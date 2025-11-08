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
  static const String _keyCounter = 'comprobante_counter';
  static const String _keyDeviceId = 'device_id';

  // Indica si ya se inicializó el contador
  bool _initialized = false;

  // Contador único para todos los comprobantes
  int _counter = 0;

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

      _counter = prefs.getInt(_keyCounter) ?? 1;
      _deviceId = prefs.getString(_keyDeviceId) ?? '01';

      // Cargar origen desde la base de datos
      final origenDb = await AppDatabase.instance.getConfiguracion('origen');
      _origen = origenDb ?? 'AYS';

      // Asegurar que el contador esté dentro del rango válido
      if (_counter < 1 || _counter > _maxCounter) {
        _counter = 1;
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error inicializando ComprobanteManager: $e');
      // En caso de error, usar valores predeterminados
      _counter = 1;
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
  Future<String> getNextBusComprobante() async {
    await _ensureInitialized();

    // Recargar origen desde la base de datos para asegurar que esté actualizado
    await getOrigen();

    // Formatear el número de comprobante a 6 dígitos con ceros a la izquierda
    final formattedNumber = _getFormattedCounter();

    // Combinar: ORIGEN-ID-NUMERO (ej: AYS-01-000001)
    final fullComprobante = '$_origen-$_deviceId-$formattedNumber';

    // Incrementar y guardar el contador para el próximo uso
    await _incrementCounter();

    return fullComprobante;
  }

  /// Obtiene y genera el siguiente número de comprobante para carga
  Future<String> getNextCargoComprobante() async {
    await _ensureInitialized();

    // Recargar origen desde la base de datos para asegurar que esté actualizado
    await getOrigen();

    // Usar el mismo formato que los tickets de bus
    final formattedNumber = _getFormattedCounter();

    // Combinar: ORIGEN-ID-NUMERO (ej: COY-01-000001)
    final fullComprobante = '$_origen-$_deviceId-$formattedNumber';

    // Incrementar y guardar el contador para el próximo uso
    await _incrementCounter();

    return fullComprobante;
  }

  /// Incrementa el contador y lo guarda en SharedPreferences
  Future<void> _incrementCounter() async {
    _counter++;

    // Si llegó al máximo, reiniciar a 1
    if (_counter > _maxCounter) {
      _counter = 1;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCounter, _counter);
    } catch (e) {
      debugPrint('Error al guardar contador: $e');
    }
  }

  /// Formatea el contador actual a 6 dígitos
  String _getFormattedCounter() {
    return _counter.toString().padLeft(6, '0');
  }

  /// Asegura que la clase esté inicializada antes de usarla
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Reinicia manualmente el contador
  Future<void> resetCounter() async {
    await _ensureInitialized();

    try {
      _counter = 1;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCounter, _counter);
    } catch (e) {
      debugPrint('Error al resetear contador manualmente: $e');
    }
  }

  /// Obtiene el número actual del contador (sin incrementarlo)
  Future<int> getCurrentCounter() async {
    await _ensureInitialized();
    return _counter;
  }

  /// Obtiene el número actual del contador formateado a 6 dígitos
  Future<String> getCurrentFormattedCounter() async {
    await _ensureInitialized();
    return _counter.toString().padLeft(6, '0');
  }

  /// Obtiene el número de comprobante completo con el ID del dispositivo sin incrementar
  Future<String> getCurrentFullComprobante() async {
    await _ensureInitialized();
    await getOrigen();
    final formattedNumber = _getFormattedCounter();
    return '$_origen-$_deviceId-$formattedNumber';
  }
}