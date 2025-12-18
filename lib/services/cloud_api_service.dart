import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

class CloudApiService {
  static const String defaultBaseUrl = 'https://api.danteaguerorodriguez.work';
  static const Duration normalTimeout = Duration(seconds: 15);
  static const Duration healthCheckTimeout = Duration(seconds: 5);

  // Headers comunes
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Obtener URL configurada o usar la por defecto
  static Future<String> getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cloud_api_url') ?? defaultBaseUrl;
    } catch (e) {
      debugPrint('Error obteniendo URL del servidor: $e');
      return defaultBaseUrl;
    }
  }

  // Verificar si el modo solo offline está activado
  static Future<bool> isModoSoloOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('modo_solo_offline') ?? false;
    } catch (e) {
      debugPrint('Error verificando modo offline: $e');
      return false;
    }
  }

  // 1. AUTENTICACIÓN

  /// Login en el servidor cloud
  /// Retorna el objeto del usuario si es exitoso, null si falla
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    // Verificar modo offline
    if (await isModoSoloOffline()) {
      debugPrint('Modo solo offline activado - login cloud omitido');
      return null;
    }

    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: headers,
            body: json.encode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(normalTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Guardar usuario en SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cloud_user', json.encode(data['data']));
          debugPrint('Login cloud exitoso para usuario: $username');
          return data['data'];
        }
      }

      debugPrint('Error en login: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error de conexión en login: $e');
      return null;
    }
  }

  // 2. SINCRONIZACIÓN DE VENTAS (PUSH)

  /// Sincroniza ventas locales no sincronizadas con el servidor
  /// Retorna un mapa con el resumen de la sincronización
  static Future<Map<String, dynamic>> sincronizarVentasLocal() async {
    if (await isModoSoloOffline()) {
      return {
        'success': false,
        'message': 'Modo solo offline activado',
        'enviados': 0,
        'errores': 0,
      };
    }

    try {
      final baseUrl = await getBaseUrl();
      final db = AppDatabase.instance;

      // Obtener ventas no sincronizadas
      final ventasPendientes = await db.obtenerVentasNoSincronizadas();

      if (ventasPendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay ventas pendientes de sincronizar',
          'enviados': 0,
          'errores': 0,
        };
      }

      int enviados = 0;
      int errores = 0;
      List<String> comprobantesEnviados = [];

      for (var venta in ventasPendientes) {
        try {
          // Parsear datos completos (es un JSON string)
          final datosCompletos = json.decode(venta['datos_completos'] as String);

          final response = await http
              .post(
                Uri.parse('$baseUrl/api/sincronizar'),
                headers: headers,
                body: json.encode({
                  'tipo': 'boletos',
                  'datos': datosCompletos,
                }),
              )
              .timeout(normalTimeout);

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              // Marcar como sincronizado
              await db.marcarComoSincronizado(venta['comprobante'] as String);
              comprobantesEnviados.add(venta['comprobante'] as String);
              enviados++;
            } else {
              errores++;
              debugPrint('Error sincronizando venta ${venta['comprobante']}: ${data['message']}');
            }
          } else {
            errores++;
            debugPrint('Error HTTP sincronizando venta ${venta['comprobante']}: ${response.statusCode}');
          }
        } catch (e) {
          errores++;
          debugPrint('Error procesando venta ${venta['comprobante']}: $e');
        }
      }

      // Guardar última sincronización exitosa si hubo al menos una venta enviada
      if (enviados > 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ultima_sincronizacion', DateTime.now().toIso8601String());
      }

      return {
        'success': errores == 0,
        'message': 'Sincronizadas $enviados de ${ventasPendientes.length} ventas',
        'enviados': enviados,
        'errores': errores,
        'comprobantes': comprobantesEnviados,
      };
    } catch (e) {
      debugPrint('Error en sincronizarVentasLocal: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'enviados': 0,
        'errores': 0,
      };
    }
  }

  // 3. SINCRONIZACIÓN DE CIERRES DE CAJA (PUSH)

  /// Sincroniza cierres de caja locales no sincronizados con el servidor
  /// Retorna un mapa con el resumen de la sincronización
  static Future<Map<String, dynamic>> sincronizarCierresLocal() async {
    if (await isModoSoloOffline()) {
      return {
        'success': false,
        'message': 'Modo solo offline activado',
        'enviados': 0,
        'errores': 0,
      };
    }

    try {
      final baseUrl = await getBaseUrl();
      final db = AppDatabase.instance;

      // Obtener cierres no sincronizados
      final cierresPendientes = await db.obtenerCierresNoSincronizados();

      if (cierresPendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay cierres pendientes de sincronizar',
          'enviados': 0,
          'errores': 0,
        };
      }

      int enviados = 0;
      int errores = 0;

      for (var cierre in cierresPendientes) {
        try {
          final response = await http
              .post(
                Uri.parse('$baseUrl/api/sincronizar'),
                headers: headers,
                body: json.encode({
                  'tipo': 'cierres',
                  'datos': cierre,
                }),
              )
              .timeout(normalTimeout);

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              // Marcar cierre como sincronizado
              await db.marcarCierreComoSincronizado(cierre['id'] as int);
              enviados++;
            } else {
              errores++;
              debugPrint('Error sincronizando cierre ${cierre['id']}: ${data['message']}');
            }
          } else {
            errores++;
            debugPrint('Error HTTP sincronizando cierre: ${response.statusCode}');
          }
        } catch (e) {
          errores++;
          debugPrint('Error procesando cierre: $e');
        }
      }

      return {
        'success': errores == 0,
        'message': 'Sincronizados $enviados de ${cierresPendientes.length} cierres',
        'enviados': enviados,
        'errores': errores,
      };
    } catch (e) {
      debugPrint('Error en sincronizarCierresLocal: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'enviados': 0,
        'errores': 0,
      };
    }
  }

  // 4. DESCARGA DE TARIFAS (PULL)

  /// Descarga tarifas desde el servidor y actualiza la base de datos local
  /// Retorna true si fue exitoso
  static Future<bool> descargarTarifas(String sucursal) async {
    if (await isModoSoloOffline()) {
      debugPrint('Modo solo offline activado - descarga de tarifas omitida');
      return false;
    }

    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/sincronizar/tarifas?sucursal=$sucursal'),
            headers: headers,
          )
          .timeout(normalTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final tarifas = data['data'] as List;
          final db = AppDatabase.instance;

          // Actualizar tarifas en la base de datos local
          for (var tarifa in tarifas) {
            await db.actualizarTarifaDesdeCloud(tarifa);
          }

          debugPrint('Descargadas ${tarifas.length} tarifas desde el cloud');
          return true;
        }
      }

      debugPrint('Error descargando tarifas: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error de conexión descargando tarifas: $e');
      return false;
    }
  }

  // 5. DESCARGA DE HORARIOS (PULL)

  /// Descarga horarios desde el servidor y actualiza la base de datos local
  /// Retorna true si fue exitoso
  static Future<bool> descargarHorarios(String sucursal) async {
    if (await isModoSoloOffline()) {
      debugPrint('Modo solo offline activado - descarga de horarios omitida');
      return false;
    }

    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/sincronizar/horarios?sucursal=$sucursal'),
            headers: headers,
          )
          .timeout(normalTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final horarios = data['data'] as List;
          final db = AppDatabase.instance;

          // Actualizar horarios en la base de datos local
          for (var horario in horarios) {
            await db.actualizarHorarioDesdeCloud(horario);
          }

          debugPrint('Descargados ${horarios.length} horarios desde el cloud');
          return true;
        }
      }

      debugPrint('Error descargando horarios: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error de conexión descargando horarios: $e');
      return false;
    }
  }

  // 6. DESCARGA DE USUARIOS (PULL)

  /// Descarga usuarios desde el servidor y actualiza la base de datos local
  /// Retorna true si fue exitoso
  static Future<bool> descargarUsuarios() async {
    if (await isModoSoloOffline()) {
      debugPrint('Modo solo offline activado - descarga de usuarios omitida');
      return false;
    }

    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/sincronizar/usuarios'),
            headers: headers,
          )
          .timeout(normalTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final usuarios = data['data'] as List;
          final db = AppDatabase.instance;

          // Actualizar usuarios en la base de datos local
          for (var usuario in usuarios) {
            await db.actualizarUsuarioDesdeCloud(usuario);
          }

          debugPrint('Descargados ${usuarios.length} usuarios desde el cloud');
          return true;
        }
      }

      debugPrint('Error descargando usuarios: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error de conexión descargando usuarios: $e');
      return false;
    }
  }

  // 7. REGISTRO DE VENTA DIRECTA EN CLOUD

  /// Registra una venta directamente en el cloud (cuando hay conexión)
  /// Retorna true si fue exitoso
  static Future<bool> registrarVenta(Map<String, dynamic> boleto) async {
    if (await isModoSoloOffline()) {
      debugPrint('Modo solo offline activado - registro directo omitido');
      return false;
    }

    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/boletos'),
            headers: headers,
            body: json.encode(boleto),
          )
          .timeout(normalTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('Venta ${boleto['comprobante']} registrada en cloud exitosamente');
          return true;
        }
      }

      debugPrint('Error registrando venta en cloud: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error de conexión registrando venta: $e');
      return false;
    }
  }

  // 8. CONSULTA DE ASIENTOS OCUPADOS

  /// Obtiene los asientos ocupados de una salida específica desde el cloud
  /// Retorna lista de números de asientos ocupados
  static Future<List<int>> obtenerAsientosOcupados(int salidaId) async {
    if (await isModoSoloOffline()) {
      debugPrint('Modo solo offline activado - consulta de asientos cloud omitida');
      return [];
    }

    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/salidas/$salidaId/asientos'),
            headers: headers,
          )
          .timeout(normalTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final asientos = data['data'] as List;
          return asientos.map((a) => a['numero_asiento'] as int).toList();
        }
      }

      debugPrint('Error consultando asientos ocupados: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error de conexión consultando asientos: $e');
      return [];
    }
  }

  // 9. HEALTH CHECK

  /// Verifica si el servidor está disponible
  /// Retorna true si hay conexión exitosa
  static Future<bool> verificarConexion() async {
    if (await isModoSoloOffline()) {
      return false;
    }

    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/health'),
            headers: headers,
          )
          .timeout(healthCheckTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      debugPrint('No hay conexión con el servidor cloud: $e');
      return false;
    }
  }

  // 10. MÉTODOS AUXILIARES

  /// Obtiene la última sincronización exitosa
  static Future<DateTime?> getUltimaSincronizacion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ultimaSync = prefs.getString('ultima_sincronizacion');
      if (ultimaSync != null) {
        return DateTime.parse(ultimaSync);
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo última sincronización: $e');
      return null;
    }
  }

  /// Sincroniza todo (tarifas, horarios, usuarios, ventas, cierres)
  static Future<Map<String, dynamic>> sincronizarTodo(String sucursal) async {
    final resultados = <String, dynamic>{};

    // Descargar datos desde cloud
    resultados['tarifas'] = await descargarTarifas(sucursal);
    resultados['horarios'] = await descargarHorarios(sucursal);
    resultados['usuarios'] = await descargarUsuarios();

    // Subir datos locales al cloud
    resultados['ventas'] = await sincronizarVentasLocal();
    resultados['cierres'] = await sincronizarCierresLocal();

    final todoExitoso = resultados['tarifas'] == true &&
        resultados['horarios'] == true &&
        resultados['usuarios'] == true &&
        (resultados['ventas']['success'] == true) &&
        (resultados['cierres']['success'] == true);

    return {
      'success': todoExitoso,
      'detalles': resultados,
    };
  }
}
