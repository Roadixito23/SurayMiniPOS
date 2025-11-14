import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

/// Clase para gestionar los números de comprobantes en la aplicación
class ComprobanteManager {
  // Singleton pattern
  static final ComprobanteManager _instance = ComprobanteManager._internal();

  factory ComprobanteManager() {
    return _instance;
  }

  ComprobanteManager._internal();

  // Constantes para las claves de SharedPreferences
  static const String _keyDeviceId = 'device_id';

  // Indica si ya se inicializó el contador
  bool _initialized = false;

  // Contadores individualizados por tipo de boleto
  final Map<String, int> _counters = {
    'PUBLICO GENERAL': 1,
    'ESCOLAR': 1,
    'ADULTO MAYOR': 1,
    'INTERMEDIO 15KM': 1,
    'INTERMEDIO 50KM': 1,
    'CARGO': 1, // Para servicios de carga
  };

  // ID del dispositivo
  String _deviceId = '01';

  // Origen (AYS o COY)
  String _origen = 'AYS';

  // Número máximo de comprobante (6 dígitos)
  static const int _maxCounter = 999999;

  /// Inicializa el contador y el ID del dispositivo desde el almacenamiento local
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar contadores individualizados por tipo de boleto
      for (var tipo in _counters.keys) {
        final keyCounter = 'comprobante_counter_${tipo.replaceAll(' ', '_')}';
        _counters[tipo] = prefs.getInt(keyCounter) ?? 1;

        // Asegurar que el contador esté dentro del rango válido
        if (_counters[tipo]! < 1 || _counters[tipo]! > _maxCounter) {
          _counters[tipo] = 1;
        }
      }

      _deviceId = prefs.getString(_keyDeviceId) ?? '01';

      // Cargar origen desde la base de datos
      final origenDb = await AppDatabase.instance.getConfiguracion('origen');
      _origen = origenDb ?? 'AYS';

      _initialized = true;
    } catch (e) {
      debugPrint('Error inicializando ComprobanteManager: $e');
      // En caso de error, usar valores predeterminados
      _deviceId = '01';
      _origen = 'AYS';
      _initialized = true;
    }
  }

  /// Obtiene el ID del dispositivo actual
  Future<String> getDeviceId() async {
    if (!_initialized) {
      await initialize();
    }
    return _deviceId;
  }

  /// Obtiene el origen actual
  Future<String> getOrigen() async {
    if (!_initialized) {
      await initialize();
    }
    // Recargar desde la base de datos para obtener el valor más reciente
    final origenDb = await AppDatabase.instance.getConfiguracion('origen');
    _origen = origenDb ?? 'AYS';
    return _origen;
  }

  /// Actualiza el ID del dispositivo
  Future<void> updateDeviceId(String newDeviceId) async {
    _deviceId = newDeviceId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDeviceId, newDeviceId);
    } catch (e) {
      debugPrint('Error al guardar device_id: $e');
    }
  }

  /// Obtiene y genera el siguiente número de comprobante para boletos de bus
  /// [tipoBoleto] puede ser: "PUBLICO GENERAL", "ESCOLAR", "ADULTO MAYOR", "INTERMEDIO 15KM", "INTERMEDIO 50KM"
  /// [idSecretario] ID del secretario logueado (01-99)
  /// [origenActual] Origen actual seleccionado al iniciar sesión (AYS o COY)
  Future<String> getNextBusComprobante(String tipoBoleto, {String? idSecretario, String? origenActual}) async {
    await _ensureInitialized();

    // Usar el ID de secretario proporcionado o el device_id por defecto
    final secretarioId = idSecretario ?? _deviceId;

    // Usar el origen proporcionado o el origen de la base de datos
    final origen = origenActual ?? await getOrigen();

    // Verificar que el tipo de boleto sea válido
    if (!_counters.containsKey(tipoBoleto)) {
      debugPrint('Tipo de boleto no válido: $tipoBoleto, usando PUBLICO GENERAL');
      tipoBoleto = 'PUBLICO GENERAL';
    }

    // Formatear el número de comprobante a 6 dígitos con ceros a la izquierda
    final formattedNumber = _getFormattedCounter(tipoBoleto);

    // Combinar: ORIGEN-ID_SECRETARIO-NUMERO (ej: AYS-01-000001)
    final fullComprobante = '$origen-$secretarioId-$formattedNumber';

    // Incrementar y guardar el contador para el próximo uso
    await _incrementCounter(tipoBoleto);

    return fullComprobante;
  }

  /// Obtiene y genera el siguiente número de comprobante para carga
  /// [idSecretario] ID del secretario logueado (01-99)
  /// [origenActual] Origen actual seleccionado al iniciar sesión (AYS o COY)
  Future<String> getNextCargoComprobante({String? idSecretario, String? origenActual}) async {
    await _ensureInitialized();

    // Usar el ID de secretario proporcionado o el device_id por defecto
    final secretarioId = idSecretario ?? _deviceId;

    // Usar el origen proporcionado o el origen de la base de datos
    final origen = origenActual ?? await getOrigen();

    // Usar el mismo formato que los tickets de bus
    final formattedNumber = _getFormattedCounter('CARGO');

    // Combinar: ORIGEN-ID_SECRETARIO-NUMERO (ej: COY-01-000001)
    final fullComprobante = '$origen-$secretarioId-$formattedNumber';

    // Incrementar y guardar el contador para el próximo uso
    await _incrementCounter('CARGO');

    return fullComprobante;
  }

  /// Incrementa el contador y lo guarda en SharedPreferences
  Future<void> _incrementCounter(String tipoBoleto) async {
    _counters[tipoBoleto] = (_counters[tipoBoleto] ?? 1) + 1;

    // Si llegó al máximo, reiniciar a 1
    if (_counters[tipoBoleto]! > _maxCounter) {
      _counters[tipoBoleto] = 1;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final keyCounter = 'comprobante_counter_${tipoBoleto.replaceAll(' ', '_')}';
      await prefs.setInt(keyCounter, _counters[tipoBoleto]!);
    } catch (e) {
      debugPrint('Error al guardar contador para $tipoBoleto: $e');
    }
  }

  /// Formatea el contador actual a 6 dígitos
  String _getFormattedCounter(String tipoBoleto) {
    return (_counters[tipoBoleto] ?? 1).toString().padLeft(6, '0');
  }

  /// Asegura que la clase esté inicializada antes de usarla
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Reinicia manualmente todos los contadores
  Future<void> resetCounter() async {
    await _ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      for (var tipo in _counters.keys) {
        _counters[tipo] = 1;
        final keyCounter = 'comprobante_counter_${tipo.replaceAll(' ', '_')}';
        await prefs.setInt(keyCounter, 1);
      }
    } catch (e) {
      debugPrint('Error al resetear contadores manualmente: $e');
    }
  }

  /// Obtiene el número actual del contador (sin incrementarlo) para un tipo de boleto
  Future<int> getCurrentCounter(String tipoBoleto) async {
    await _ensureInitialized();
    return _counters[tipoBoleto] ?? 1;
  }

  /// Obtiene el número actual del contador formateado a 6 dígitos para un tipo de boleto
  Future<String> getCurrentFormattedCounter(String tipoBoleto) async {
    await _ensureInitialized();
    return (_counters[tipoBoleto] ?? 1).toString().padLeft(6, '0');
  }

  /// Obtiene el número de comprobante completo con el ID del dispositivo sin incrementar para un tipo de boleto
  Future<String> getCurrentFullComprobante(String tipoBoleto) async {
    await _ensureInitialized();
    await getOrigen();
    final formattedNumber = _getFormattedCounter(tipoBoleto);
    return '$_origen-$_deviceId-$formattedNumber';
  }

  /// Obtiene el último número de comprobante vendido (el anterior al actual) para un tipo de boleto
  Future<String> getLastSoldComprobante(String tipoBoleto) async {
    await _ensureInitialized();
    await getOrigen();

    int lastNumber = (_counters[tipoBoleto] ?? 1) - 1;

    // Si es 0, significa que no se ha vendido ninguno aún
    if (lastNumber < 1) {
      return 'Sin ventas';
    }

    final formattedNumber = lastNumber.toString().padLeft(6, '0');
    return '$_origen-$_deviceId-$formattedNumber';
  }

  /// Obtiene todos los contadores actuales
  Future<Map<String, int>> getAllCounters() async {
    await _ensureInitialized();
    return Map.from(_counters);
  }
}