import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

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
  }) async {
    final venta = {
      'tipo': 'bus',
      'destino': destino,
      'horario': horario,
      'asiento': asiento,
      'valor': valor,
      'comprobante': comprobante,
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
  }) async {
    final venta = {
      'tipo': 'cargo',
      'remitente': remitente,
      'destinatario': destinatario,
      'destino': destino,
      'articulo': articulo,
      'valor': valor,
      'comprobante': comprobante,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'fecha': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'hora': DateFormat('HH:mm:ss').format(DateTime.now()),
    };

    await _guardarVenta(venta);
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
  }) async {
    try {
      await _ensureInitialized();

      final ventas = await getVentasDiarias();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final hora = DateFormat('HH:mm:ss').format(DateTime.now());

      // Calcular totales
      double totalBus = 0;
      double totalCargo = 0;
      int cantidadBus = 0;
      int cantidadCargo = 0;

      // Destinos para bus
      Map<String, Map<String, dynamic>> destinosBus = {};

      // Destinos para cargo
      Map<String, Map<String, dynamic>> destinosCargo = {};

      for (var venta in ventas) {
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
        'destinosBus': destinosBus,
        'destinosCargo': destinosCargo,
        'ventas': ventas
      };

      // Guardar cierre de caja
      await _guardarCierreCaja(cierre);

      // Actualizar último cierre
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyUltimoCierre, timestamp);

      // Limpiar ventas diarias
      await _saveJsonToFile(_ventasFileName, []);

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