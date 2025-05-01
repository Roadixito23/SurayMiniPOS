import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clase para gestionar los números de comprobantes en la aplicación
class ComprobanteManager {
  // Singleton pattern
  static final ComprobanteManager _instance = ComprobanteManager._internal();

  factory ComprobanteManager() {
    return _instance;
  }

  ComprobanteManager._internal();

  // Constante para la clave de SharedPreferences
  static const String _keyCounter = 'comprobante_counter';

  // Indica si ya se inicializó el contador
  bool _initialized = false;

  // Contador único para todos los comprobantes
  int _counter = 0;

  // Número máximo de comprobante (6 dígitos)
  static const int _maxCounter = 999999;

  /// Inicializa el contador desde el almacenamiento local
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      _counter = prefs.getInt(_keyCounter) ?? 1;

      // Asegurar que el contador esté dentro del rango válido
      if (_counter < 1 || _counter > _maxCounter) {
        _counter = 1;
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error inicializando ComprobanteManager: $e');
      // En caso de error, usar valor predeterminado
      _counter = 1;
      _initialized = true;
    }
  }

  /// Obtiene y genera el siguiente número de comprobante para boletos de bus
  Future<String> getNextBusComprobante() async {
    await _ensureInitialized();

    // Formatear el número de comprobante a 6 dígitos con ceros a la izquierda
    final formattedNumber = _getFormattedCounter();

    // Incrementar y guardar el contador para el próximo uso
    _incrementCounter();

    return formattedNumber;
  }

  /// Obtiene y genera el siguiente número de comprobante para carga
  Future<String> getNextCargoComprobante() async {
    await _ensureInitialized();

    // Usar el mismo formato que los tickets de bus, sin prefijo
    final formattedNumber = _getFormattedCounter();

    // Incrementar y guardar el contador para el próximo uso
    _incrementCounter();

    return formattedNumber;
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
}