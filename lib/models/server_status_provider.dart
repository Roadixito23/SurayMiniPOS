import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para gestionar el estado de conexión del servidor
/// En modo offline, solo se permiten ventas desde la sucursal de origen
/// En modo online, se permite vender desde cualquier origen
class ServerStatusProvider with ChangeNotifier {
  bool _isOnline = true; // Por defecto el servidor está online
  bool _isSimulated = false; // Indica si el estado es simulado (para debug)

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get isSimulated => _isSimulated;

  ServerStatusProvider() {
    _loadStatus();
  }

  /// Carga el estado del servidor desde SharedPreferences
  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnline = prefs.getBool('server_is_online') ?? true;
      _isSimulated = prefs.getBool('server_is_simulated') ?? false;
      notifyListeners();
    } catch (e) {
      print('Error al cargar estado del servidor: $e');
    }
  }

  /// Guarda el estado del servidor en SharedPreferences
  Future<void> _saveStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('server_is_online', _isOnline);
      await prefs.setBool('server_is_simulated', _isSimulated);
    } catch (e) {
      print('Error al guardar estado del servidor: $e');
    }
  }

  /// Simula el estado del servidor (para debug)
  Future<void> simulateServerStatus(bool online) async {
    _isOnline = online;
    _isSimulated = true;
    await _saveStatus();
    notifyListeners();
  }

  /// Resetea la simulación y vuelve al estado real del servidor
  Future<void> resetSimulation() async {
    _isSimulated = false;
    _isOnline = true; // Por defecto online cuando se resetea
    await _saveStatus();
    notifyListeners();
  }

  /// Actualiza el estado real del servidor (no simulado)
  Future<void> updateServerStatus(bool online) async {
    if (_isSimulated) {
      // No actualizar si está en modo simulación
      return;
    }
    _isOnline = online;
    await _saveStatus();
    notifyListeners();
  }

  /// Obtiene un mensaje descriptivo del estado actual
  String get statusMessage {
    if (_isSimulated) {
      return _isOnline
          ? '🟢 Servidor ONLINE (Simulado)'
          : '🔴 Servidor OFFLINE (Simulado)';
    }
    return _isOnline ? '🟢 Servidor ONLINE' : '🔴 Servidor OFFLINE';
  }

  /// Obtiene el color asociado al estado
  /// Verde para online, rojo para offline
  int get statusColor {
    return _isOnline ? 0xFF4CAF50 : 0xFFF44336;
  }
}
