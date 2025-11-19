import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'app_database.dart';

/// Clase para manejar la base de datos de ventas para el cierre de caja
/// Con soporte mejorado para persistencia de archivos locales
class CajaDatabase {
  // Singleton pattern
  static final CajaDatabase _instance = CajaDatabase._internal();

  factory CajaDatabase() {
    return _instance;
  }

  CajaDatabase._internal();

  // Constantes para las claves de SharedPreferences
  static const String _keyUltimoCierre = 'ultimo_cierre';

  // Constantes para nombres de archivos
  static const String _ventasFileName = 'ventas_diarias.json';
  static const String _cierresCajaFileName = 'cierres_caja.json';
  static const String _gastosFileName = 'gastos_diarios.json';
  static const String _backupDirName = 'backups';

  // Directorio de la aplicación
  Directory? _appDirectory;
  bool _initialized = false;

  /// Inicializa la base de datos
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _appDirectory = await getApplicationDocumentsDirectory();

      // Crear directorio de backups si no existe
      final backupDir = Directory('${_appDirectory!.path}/$_backupDirName');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error inicializando CajaDatabase: $e');
      rethrow;
    }
  }

  /// Asegura que la base de datos esté inicializada
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Registra una venta de boleto de bus
  Future<void> registrarVentaBus({
    required String destino,
    required String horario,
    required String asiento,
    required double valor,
    required String comprobante,
    required String tipoBoleto, // Categoría del boleto (PUBLICO GENERAL, ESCOLAR, etc.)
    String metodoPago = 'Efectivo', // Efectivo, Tarjeta, Personalizar
    double? montoEfectivo, // Para método personalizado
    double? montoTarjeta, // Para método personalizado
  }) async {
    final venta = {
      'tipo': 'bus',
      'destino': destino,
      'horario': horario,
      'asiento': asiento,
      'valor': valor,
      'comprobante': comprobante,
      'tipoBoleto': tipoBoleto,
      'metodoPago': metodoPago,
      'montoEfectivo': metodoPago == 'Personalizar' ? (montoEfectivo ?? 0) : (metodoPago == 'Efectivo' ? valor : 0),
      'montoTarjeta': metodoPago == 'Personalizar' ? (montoTarjeta ?? 0) : (metodoPago == 'Tarjeta' ? valor : 0),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'fecha': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'hora': DateFormat('HH:mm:ss').format(DateTime.now()),
    };

    await _guardarVenta(venta);
  }

  /// Registra una venta de cargo
  Future<void> registrarVentaCargo({
    required String remitente,
    required String destinatario,
    required String destino,
    required String articulo,
    required double valor,
    required String comprobante,
    String metodoPago = 'Efectivo', // Efectivo, Tarjeta, Personalizar
    double? montoEfectivo, // Para método personalizado
    double? montoTarjeta, // Para método personalizado
  }) async {
    final venta = {
      'tipo': 'cargo',
      'remitente': remitente,
      'destinatario': destinatario,
      'destino': destino,
      'articulo': articulo,
      'valor': valor,
      'comprobante': comprobante,
      'metodoPago': metodoPago,
      'montoEfectivo': metodoPago == 'Personalizar' ? (montoEfectivo ?? 0) : (metodoPago == 'Efectivo' ? valor : 0),
      'montoTarjeta': metodoPago == 'Personalizar' ? (montoTarjeta ?? 0) : (metodoPago == 'Tarjeta' ? valor : 0),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'fecha': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'hora': DateFormat('HH:mm:ss').format(DateTime.now()),
    };

    await _guardarVenta(venta);
  }

  /// Registra un gasto
  Future<void> registrarGasto({
    required String tipoGasto, // "Combustible" o "Otros"
    required double monto,
    String? numeroMaquina, // Solo para Combustible (máx 6 caracteres alfanuméricos)
    String? chofer, // Solo para Combustible
    String? descripcion, // Solo para Otros
  }) async {
    final gasto = {
      'tipoGasto': tipoGasto,
      'monto': monto,
      'numeroMaquina': numeroMaquina,
      'chofer': chofer,
      'descripcion': descripcion,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'fecha': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'hora': DateFormat('HH:mm:ss').format(DateTime.now()),
    };

    await _guardarGasto(gasto);
  }

  /// Obtiene el número de anulaciones realizadas por un usuario en el día actual
  Future<int> contarAnulacionesDelDia(String usuario) async {
    try {
      await _ensureInitialized();

      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      List<Map<String, dynamic>> ventas = await getVentasDiarias();

      int contador = 0;
      for (var venta in ventas) {
        if (venta['anulada'] == true &&
            venta['usuarioAnulacion'] == usuario &&
            venta['fechaAnulacion'] == hoy) {
          contador++;
        }
      }

      return contador;
    } catch (e) {
      debugPrint('Error al contar anulaciones del día: $e');
      return 0;
    }
  }

  /// Anula una venta por su número de comprobante
  /// Retorna true si se anuló exitosamente, false si no se encontró la venta
  Future<bool> anularVenta({
    required String comprobante,
    required String usuario,
    String? motivo,
  }) async {
    try {
      await _ensureInitialized();

      // Obtener ventas existentes
      List<Map<String, dynamic>> ventas = await getVentasDiarias();

      // Buscar la venta por comprobante
      int indiceVenta = -1;
      Map<String, dynamic>? ventaEncontrada;

      for (int i = 0; i < ventas.length; i++) {
        if (ventas[i]['comprobante'] == comprobante) {
          // Verificar si ya está anulada
          if (ventas[i]['anulada'] == true) {
            debugPrint('La venta con comprobante $comprobante ya está anulada');
            return false;
          }
          indiceVenta = i;
          ventaEncontrada = Map<String, dynamic>.from(ventas[i]);
          break;
        }
      }

      if (indiceVenta == -1 || ventaEncontrada == null) {
        debugPrint('No se encontró venta con comprobante $comprobante');
        return false;
      }

      // Marcar la venta como anulada
      ventas[indiceVenta]['anulada'] = true;
      ventas[indiceVenta]['fechaAnulacion'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
      ventas[indiceVenta]['horaAnulacion'] = DateFormat('HH:mm:ss').format(DateTime.now());
      ventas[indiceVenta]['usuarioAnulacion'] = usuario;
      ventas[indiceVenta]['motivoAnulacion'] = motivo ?? 'Sin motivo especificado';

      // Si es una venta de bus, liberar el asiento en la base de datos
      if (ventaEncontrada['tipo'] == 'bus') {
        try {
          // Obtener AppDatabase
          final appDb = AppDatabase.instance;
          final db = await appDb.database;

          // Obtener información de la venta
          final fecha = ventaEncontrada['fecha'];
          final horario = ventaEncontrada['horario'];
          final destino = ventaEncontrada['destino'];
          final asiento = int.tryParse(ventaEncontrada['asiento'].toString()) ?? 0;

          // Obtener el ID de la salida
          final salidaId = await db.rawQuery(
            '''
            SELECT id FROM salidas
            WHERE fecha = ? AND horario = ? AND destino = ? AND activo = 1
            ''',
            [fecha, horario, destino],
          );

          if (salidaId.isNotEmpty) {
            final id = salidaId.first['id'] as int;

            // Liberar el asiento
            await db.delete(
              'asientos_reservados',
              where: 'salida_id = ? AND numero_asiento = ?',
              whereArgs: [id, asiento],
            );

            debugPrint('Asiento $asiento liberado para salida $id');
          }
        } catch (e) {
          debugPrint('Error al liberar asiento: $e');
          // Continuar con la anulación aunque falle la liberación del asiento
        }
      }

      // Guardar la lista actualizada
      await _saveJsonToFile(_ventasFileName, ventas);

      debugPrint('Venta $comprobante anulada exitosamente');
      return true;
    } catch (e) {
      debugPrint('Error al anular venta: $e');
      return false;
    }
  }

  /// Guarda un gasto en la base de datos
  Future<void> _guardarGasto(Map<String, dynamic> gasto) async {
    try {
      await _ensureInitialized();

      // Obtener gastos existentes
      List<Map<String, dynamic>> gastos = await getGastosDiarios();

      // Añadir el nuevo gasto
      gastos.add(gasto);

      // Guardar la lista actualizada en archivo
      await _saveJsonToFile(_gastosFileName, gastos);
    } catch (e) {
      debugPrint('Error al guardar gasto: $e');
      rethrow;
    }
  }

  /// Obtiene todos los gastos desde el último cierre
  Future<List<Map<String, dynamic>>> getGastosDiarios() async {
    try {
      await _ensureInitialized();

      final gastosFile = File('${_appDirectory!.path}/$_gastosFileName');

      // Si el archivo no existe, devolver una lista vacía
      if (!await gastosFile.exists()) {
        return [];
      }

      // Leer y decodificar el archivo
      final String gastosJson = await gastosFile.readAsString();
      if (gastosJson.isEmpty) {
        return [];
      }

      List<dynamic> gastosList = jsonDecode(gastosJson);

      // Verificar integridad de datos si hay checksum
      if (gastosList.isNotEmpty && gastosList.last is Map && gastosList.last.containsKey('_checksum')) {
        final checksumMap = gastosList.removeLast();
        final storedChecksum = checksumMap['_checksum'];
        final calculatedChecksum = _calculateChecksum(jsonEncode(gastosList));

        if (storedChecksum != calculatedChecksum) {
          debugPrint('Advertencia: Checksum de gastos no coincide, posible corrupción de datos');
          // Recuperar datos de respaldo si es necesario
          return await _recuperarDesdeBackup(_gastosFileName) ?? [];
        }
      }

      // Convertir a lista de mapas
      return gastosList.map((g) => Map<String, dynamic>.from(g)).toList();
    } catch (e) {
      debugPrint('Error al obtener gastos diarios: $e');

      // Intentar recuperar desde backup
      final backupData = await _recuperarDesdeBackup(_gastosFileName);
      if (backupData != null) {
        return backupData;
      }
      return [];
    }
  }

  /// Guarda una venta en la base de datos
  Future<void> _guardarVenta(Map<String, dynamic> venta) async {
    try {
      await _ensureInitialized();

      // Obtener ventas existentes
      List<Map<String, dynamic>> ventas = await getVentasDiarias();

      // Añadir la nueva venta
      ventas.add(venta);

      // Guardar la lista actualizada en archivo
      await _saveJsonToFile(_ventasFileName, ventas);

      // Crear backup automático después de cada 10 ventas
      if (ventas.length % 10 == 0) {
        await crearBackup();
      }
    } catch (e) {
      debugPrint('Error al guardar venta: $e');
      rethrow;
    }
  }

  /// Obtiene todas las ventas desde el último cierre
  Future<List<Map<String, dynamic>>> getVentasDiarias() async {
    try {
      await _ensureInitialized();

      final ventasFile = File('${_appDirectory!.path}/$_ventasFileName');

      // Si el archivo no existe, devolver una lista vacía
      if (!await ventasFile.exists()) {
        return [];
      }

      // Leer y decodificar el archivo
      final String ventasJson = await ventasFile.readAsString();
      if (ventasJson.isEmpty) {
        return [];
      }

      List<dynamic> ventasList = jsonDecode(ventasJson);

      // Verificar integridad de datos si hay checksum
      if (ventasList.isNotEmpty && ventasList.last is Map && ventasList.last.containsKey('_checksum')) {
        final checksumMap = ventasList.removeLast();
        final storedChecksum = checksumMap['_checksum'];
        final calculatedChecksum = _calculateChecksum(jsonEncode(ventasList));

        if (storedChecksum != calculatedChecksum) {
          debugPrint('Advertencia: Checksum de ventas no coincide, posible corrupción de datos');
          // Recuperar datos de respaldo si es necesario
          return await _recuperarDesdeBackup(_ventasFileName) ?? [];
        }
      }

      // Convertir a lista de mapas
      return ventasList.map((v) => Map<String, dynamic>.from(v)).toList();
    } catch (e) {
      debugPrint('Error al obtener ventas diarias: $e');

      // Intentar recuperar desde backup
      final backupData = await _recuperarDesdeBackup(_ventasFileName);
      if (backupData != null) {
        return backupData;
      }
      return [];
    }
  }

  /// Obtiene la fecha del último cierre de caja
  Future<DateTime?> getUltimoCierre() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Si no hay último cierre, devolver null
      if (!prefs.containsKey(_keyUltimoCierre)) {
        return null;
      }

      // Obtener timestamp del último cierre
      int timestamp = prefs.getInt(_keyUltimoCierre) ?? 0;
      if (timestamp == 0) return null;

      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      debugPrint('Error al obtener último cierre: $e');
      return null;
    }
  }

  /// Realiza un cierre de caja
  Future<Map<String, dynamic>> realizarCierreCaja({
    required String usuario,
    String? observaciones,
    List<String>? archivosAdjuntos,
  }) async {
    try {
      await _ensureInitialized();

      final ventas = await getVentasDiarias();
      final gastos = await getGastosDiarios();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final hora = DateFormat('HH:mm:ss').format(DateTime.now());

      // Calcular totales
      double totalBus = 0;
      double totalCargo = 0;
      int cantidadBus = 0;
      int cantidadCargo = 0;

      // Totales por método de pago
      double totalEfectivo = 0;
      double totalTarjeta = 0;

      // Destinos para bus
      Map<String, Map<String, dynamic>> destinosBus = {};

      // Destinos para cargo
      Map<String, Map<String, dynamic>> destinosCargo = {};

      // Control de caja por tipo de boleto
      Map<String, Map<String, dynamic>> controlCaja = {};

      for (var venta in ventas) {
        // Excluir ventas anuladas del cálculo de totales
        if (venta['anulada'] == true) {
          continue;
        }

        // Sumar métodos de pago
        totalEfectivo += (venta['montoEfectivo'] ?? 0.0);
        totalTarjeta += (venta['montoTarjeta'] ?? 0.0);

        if (venta['tipo'] == 'bus') {
          totalBus += venta['valor'];
          cantidadBus++;

          // Agrupar por destino (bus)
          final destino = venta['destino'];
          if (!destinosBus.containsKey(destino)) {
            destinosBus[destino] = {'cantidad': 0, 'total': 0.0};
          }
          destinosBus[destino]!['cantidad'] = destinosBus[destino]!['cantidad'] + 1;
          destinosBus[destino]!['total'] = destinosBus[destino]!['total'] + venta['valor'];

          // Control de caja por tipo de boleto
          final tipoBoleto = venta['tipoBoleto'] ?? 'PUBLICO GENERAL';
          final comprobante = venta['comprobante'] ?? '';

          if (!controlCaja.containsKey(tipoBoleto)) {
            controlCaja[tipoBoleto] = {
              'tipo': tipoBoleto,
              'primerComprobante': comprobante,
              'ultimoComprobante': comprobante,
              'cantidad': 0,
              'subtotal': 0.0,
            };
          }

          controlCaja[tipoBoleto]!['ultimoComprobante'] = comprobante;
          controlCaja[tipoBoleto]!['cantidad'] = controlCaja[tipoBoleto]!['cantidad'] + 1;
          controlCaja[tipoBoleto]!['subtotal'] = controlCaja[tipoBoleto]!['subtotal'] + venta['valor'];
        } else if (venta['tipo'] == 'cargo') {
          totalCargo += venta['valor'];
          cantidadCargo++;

          // Agrupar por destino (cargo)
          final destino = venta['destino'];
          if (!destinosCargo.containsKey(destino)) {
            destinosCargo[destino] = {'cantidad': 0, 'total': 0.0};
          }
          destinosCargo[destino]!['cantidad'] = destinosCargo[destino]!['cantidad'] + 1;
          destinosCargo[destino]!['total'] = destinosCargo[destino]!['total'] + venta['valor'];
        }
      }

      // Calcular totales de gastos
      double totalGastos = 0;
      for (var gasto in gastos) {
        totalGastos += (gasto['monto'] ?? 0.0);
      }

      // Efectivo final (restar gastos)
      double efectivoFinal = totalEfectivo - totalGastos;

      // Copiar archivos adjuntos al directorio de cierres si existen
      List<String> archivosCopiados = [];
      if (archivosAdjuntos != null && archivosAdjuntos.isNotEmpty) {
        final cierresDir = Directory('${_appDirectory!.path}/cierres_adjuntos');
        if (!await cierresDir.exists()) {
          await cierresDir.create(recursive: true);
        }

        final cierreFecha = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        for (int i = 0; i < archivosAdjuntos.length; i++) {
          try {
            final archivoOriginal = File(archivosAdjuntos[i]);
            if (await archivoOriginal.exists()) {
              final extension = archivoOriginal.path.split('.').last;
              final nombreNuevo = 'cierre_${cierreFecha}_adjunto_$i.$extension';
              final rutaDestino = '${cierresDir.path}/$nombreNuevo';
              await archivoOriginal.copy(rutaDestino);
              archivosCopiados.add(rutaDestino);
            }
          } catch (e) {
            debugPrint('Error al copiar archivo adjunto: $e');
          }
        }
      }

      // Crear informe de cierre
      final cierre = {
        'timestamp': timestamp,
        'fecha': fecha,
        'hora': hora,
        'usuario': usuario,
        'observaciones': observaciones ?? '',
        'totalBus': totalBus,
        'totalCargo': totalCargo,
        'total': totalBus + totalCargo,
        'cantidadBus': cantidadBus,
        'cantidadCargo': cantidadCargo,
        'cantidad': cantidadBus + cantidadCargo,
        'totalEfectivo': totalEfectivo,
        'totalTarjeta': totalTarjeta,
        'totalGastos': totalGastos,
        'efectivoFinal': efectivoFinal,
        'destinosBus': destinosBus,
        'destinosCargo': destinosCargo,
        'controlCaja': controlCaja.values.toList(),
        'gastos': gastos,
        'ventas': ventas,
        'archivosAdjuntos': archivosCopiados,
      };

      // Guardar cierre de caja
      await _guardarCierreCaja(cierre);

      // Actualizar último cierre
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyUltimoCierre, timestamp);

      // Limpiar ventas diarias
      await _saveJsonToFile(_ventasFileName, []);

      // Limpiar gastos diarios
      await _saveJsonToFile(_gastosFileName, []);

      // Crear backup del cierre
      await crearBackup();

      return cierre;
    } catch (e) {
      debugPrint('Error al realizar cierre de caja: $e');
      rethrow;
    }
  }

  /// Guarda un cierre de caja en la base de datos
  Future<void> _guardarCierreCaja(Map<String, dynamic> cierre) async {
    try {
      await _ensureInitialized();

      // Obtener cierres existentes
      List<Map<String, dynamic>> cierres = await getCierresCaja();

      // Añadir el nuevo cierre
      cierres.add(cierre);

      // Guardar la lista actualizada en archivo
      await _saveJsonToFile(_cierresCajaFileName, cierres);
    } catch (e) {
      debugPrint('Error al guardar cierre de caja: $e');
      rethrow;
    }
  }

  /// Obtiene el historial de cierres de caja
  Future<List<Map<String, dynamic>>> getCierresCaja() async {
    try {
      await _ensureInitialized();

      final cierresFile = File('${_appDirectory!.path}/$_cierresCajaFileName');

      // Si el archivo no existe, devolver una lista vacía
      if (!await cierresFile.exists()) {
        return [];
      }

      // Leer y decodificar el archivo
      final String cierresJson = await cierresFile.readAsString();
      if (cierresJson.isEmpty) {
        return [];
      }

      List<dynamic> cierresList = jsonDecode(cierresJson);

      // Verificar integridad de datos si hay checksum
      if (cierresList.isNotEmpty && cierresList.last is Map && cierresList.last.containsKey('_checksum')) {
        final checksumMap = cierresList.removeLast();
        final storedChecksum = checksumMap['_checksum'];
        final calculatedChecksum = _calculateChecksum(jsonEncode(cierresList));

        if (storedChecksum != calculatedChecksum) {
          debugPrint('Advertencia: Checksum de cierres no coincide, posible corrupción de datos');
          // Recuperar datos de respaldo si es necesario
          return await _recuperarDesdeBackup(_cierresCajaFileName) ?? [];
        }
      }

      // Convertir a lista de mapas
      return cierresList.map((c) => Map<String, dynamic>.from(c)).toList();
    } catch (e) {
      debugPrint('Error al obtener cierres de caja: $e');

      // Intentar recuperar desde backup
      final backupData = await _recuperarDesdeBackup(_cierresCajaFileName);
      if (backupData != null) {
        return backupData;
      }
      return [];
    }
  }

  /// Obtiene un cierre de caja específico por su timestamp
  Future<Map<String, dynamic>?> getCierreCaja(int timestamp) async {
    try {
      List<Map<String, dynamic>> cierres = await getCierresCaja();

      // Buscar el cierre con el timestamp indicado
      for (var cierre in cierres) {
        if (cierre['timestamp'] == timestamp) {
          return cierre;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error al obtener cierre de caja: $e');
      return null;
    }
  }

  /// Elimina todos los datos de cierres de caja (para depuración)
  Future<void> limpiarDatos() async {
    try {
      await _ensureInitialized();

      // Crear backup antes de limpiar
      await crearBackup();

      // Eliminar archivo de ventas
      final ventasFile = File('${_appDirectory!.path}/$_ventasFileName');
      if (await ventasFile.exists()) {
        await ventasFile.delete();
      }

      // Eliminar archivo de cierres
      final cierresFile = File('${_appDirectory!.path}/$_cierresCajaFileName');
      if (await cierresFile.exists()) {
        await cierresFile.delete();
      }

      // Eliminar archivo de gastos
      final gastosFile = File('${_appDirectory!.path}/$_gastosFileName');
      if (await gastosFile.exists()) {
        await gastosFile.delete();
      }

      // Limpiar último cierre
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUltimoCierre);
    } catch (e) {
      debugPrint('Error al limpiar datos: $e');
      rethrow;
    }
  }

  /// Crea un backup de los datos actuales
  Future<bool> crearBackup() async {
    try {
      await _ensureInitialized();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupDir = Directory('${_appDirectory!.path}/$_backupDirName');

      // Backup de ventas diarias
      final ventasFile = File('${_appDirectory!.path}/$_ventasFileName');
      if (await ventasFile.exists()) {
        final ventasBackupFile = File('${backupDir.path}/ventas_$timestamp.json');
        await ventasFile.copy(ventasBackupFile.path);
      }

      // Backup de cierres de caja
      final cierresFile = File('${_appDirectory!.path}/$_cierresCajaFileName');
      if (await cierresFile.exists()) {
        final cierresBackupFile = File('${backupDir.path}/cierres_$timestamp.json');
        await cierresFile.copy(cierresBackupFile.path);
      }

      // Backup de gastos diarios
      final gastosFile = File('${_appDirectory!.path}/$_gastosFileName');
      if (await gastosFile.exists()) {
        final gastosBackupFile = File('${backupDir.path}/gastos_$timestamp.json');
        await gastosFile.copy(gastosBackupFile.path);
      }

      // Limpiar backups antiguos (mantener solo los últimos 10)
      await _limpiarBackupsAntiguos();

      return true;
    } catch (e) {
      debugPrint('Error al crear backup: $e');
      return false;
    }
  }

  /// Limpia backups antiguos (mantiene solo los últimos 10)
  Future<void> _limpiarBackupsAntiguos() async {
    try {
      await _ensureInitialized();

      final backupDir = Directory('${_appDirectory!.path}/$_backupDirName');
      final backupFiles = await backupDir.list().toList();

      // Ordenar por nombre (que contiene timestamp)
      backupFiles.sort((a, b) => b.path.compareTo(a.path));

      // Eliminar los archivos más antiguos, dejando solo los 10 más recientes de cada tipo
      final ventasBackups = backupFiles.where((file) => file.path.contains('ventas_')).toList();
      final cierresBackups = backupFiles.where((file) => file.path.contains('cierres_')).toList();
      final gastosBackups = backupFiles.where((file) => file.path.contains('gastos_')).toList();

      if (ventasBackups.length > 10) {
        for (int i = 10; i < ventasBackups.length; i++) {
          await (ventasBackups[i] as File).delete();
        }
      }

      if (cierresBackups.length > 10) {
        for (int i = 10; i < cierresBackups.length; i++) {
          await (cierresBackups[i] as File).delete();
        }
      }

      if (gastosBackups.length > 10) {
        for (int i = 10; i < gastosBackups.length; i++) {
          await (gastosBackups[i] as File).delete();
        }
      }
    } catch (e) {
      debugPrint('Error al limpiar backups antiguos: $e');
    }
  }

  /// Restaura los datos desde el backup más reciente
  Future<bool> restaurarDesdeBackup() async {
    try {
      await _ensureInitialized();

      final backupDir = Directory('${_appDirectory!.path}/$_backupDirName');
      if (!await backupDir.exists()) {
        return false;
      }

      final backupFiles = await backupDir.list().toList();

      // Ordenar por nombre (que contiene timestamp)
      backupFiles.sort((a, b) => b.path.compareTo(a.path));

      // Encontrar el backup más reciente de cada tipo
      final ventasBackup = backupFiles.firstWhere(
            (file) => file.path.contains('ventas_'),
        orElse: () => File(''),
      );

      final cierresBackup = backupFiles.firstWhere(
            (file) => file.path.contains('cierres_'),
        orElse: () => File(''),
      );

      // Restaurar ventas
      if (ventasBackup.path.isNotEmpty) {
        final ventasFile = File('${_appDirectory!.path}/$_ventasFileName');
        await (ventasBackup as File).copy(ventasFile.path);
      }

      // Restaurar cierres
      if (cierresBackup.path.isNotEmpty) {
        final cierresFile = File('${_appDirectory!.path}/$_cierresCajaFileName');
        await (cierresBackup as File).copy(cierresFile.path);
      }

      return true;
    } catch (e) {
      debugPrint('Error al restaurar desde backup: $e');
      return false;
    }
  }

  /// Exporta todos los datos a un archivo en el almacenamiento externo
  Future<String?> exportarDatos() async {
    try {
      await _ensureInitialized();

      // Obtener directorio de descargas
      final downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir == null) {
        throw Exception('No se pudo acceder al directorio de almacenamiento externo');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final exportDir = Directory('${downloadsDir.path}/SurayPOS_Export_$timestamp');

      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Copiar archivos de datos
      final ventasFile = File('${_appDirectory!.path}/$_ventasFileName');
      if (await ventasFile.exists()) {
        final exportVentasFile = File('${exportDir.path}/$_ventasFileName');
        await ventasFile.copy(exportVentasFile.path);
      }

      final cierresFile = File('${_appDirectory!.path}/$_cierresCajaFileName');
      if (await cierresFile.exists()) {
        final exportCierresFile = File('${exportDir.path}/$_cierresCajaFileName');
        await cierresFile.copy(exportCierresFile.path);
      }

      // Crear archivo de resumen
      final ventas = await getVentasDiarias();
      final cierres = await getCierresCaja();

      // Obtener y formatear el último cierre
      final ultimoCierre = await getUltimoCierre();
      final ultimoCierreStr = ultimoCierre != null ? ultimoCierre.toIso8601String() : null;

      final resumen = {
        'fecha_exportacion': DateTime.now().toIso8601String(),
        'total_ventas': ventas.length,
        'total_cierres': cierres.length,
        'ultimo_cierre': ultimoCierreStr,
      };

      final resumenFile = File('${exportDir.path}/resumen.json');
      await resumenFile.writeAsString(jsonEncode(resumen));

      return exportDir.path;
    } catch (e) {
      debugPrint('Error al exportar datos: $e');
      return null;
    }
  }

  /// Guarda un objeto JSON en un archivo con verificación de integridad
  Future<void> _saveJsonToFile(String fileName, List<dynamic> data) async {
    try {
      await _ensureInitialized();

      final file = File('${_appDirectory!.path}/$fileName');

      // Calcular checksum
      final String jsonData = jsonEncode(data);
      final String checksum = _calculateChecksum(jsonData);

      // Añadir objeto de checksum al final
      final dataWithChecksum = List<dynamic>.from(data);
      dataWithChecksum.add({'_checksum': checksum});

      // Guardar en archivo
      await file.writeAsString(jsonEncode(dataWithChecksum));
    } catch (e) {
      debugPrint('Error al guardar archivo JSON $fileName: $e');
      rethrow;
    }
  }

  /// Calcula un checksum MD5 para verificar integridad de datos
  String _calculateChecksum(String data) {
    return md5.convert(utf8.encode(data)).toString();
  }

  /// Recupera datos desde el backup más reciente si está disponible
  Future<List<Map<String, dynamic>>?> _recuperarDesdeBackup(String fileName) async {
    try {
      await _ensureInitialized();

      final backupDir = Directory('${_appDirectory!.path}/$_backupDirName');
      if (!await backupDir.exists()) {
        return null;
      }

      final prefix = fileName.contains('ventas') ? 'ventas_' : 'cierres_';

      final backupFiles = await backupDir
          .list()
          .where((file) => file.path.contains(prefix))
          .toList();

      if (backupFiles.isEmpty) {
        return null;
      }

      // Ordenar por nombre (que contiene timestamp)
      backupFiles.sort((a, b) => b.path.compareTo(a.path));

      // Leer el backup más reciente
      final backupFile = backupFiles.first as File;
      final backupData = await backupFile.readAsString();

      if (backupData.isEmpty) {
        return null;
      }

      List<dynamic> dataList = jsonDecode(backupData);

      // Quitar checksum si existe
      if (dataList.isNotEmpty && dataList.last is Map && dataList.last.containsKey('_checksum')) {
        dataList.removeLast();
      }

      // Restaurar el archivo original
      final originalFile = File('${_appDirectory!.path}/$fileName');
      await originalFile.writeAsString(jsonEncode(dataList));

      // Convertir a lista de mapas y devolver
      return dataList.map((d) => Map<String, dynamic>.from(d)).toList();
    } catch (e) {
      debugPrint('Error al recuperar desde backup para $fileName: $e');
      return null;
    }
  }
}