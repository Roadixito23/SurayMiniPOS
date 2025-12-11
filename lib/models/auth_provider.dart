import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../services/preferences_manager.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  bool _isAuthenticated = false;
  String? _sucursalActual; // Sucursal seleccionada al inicio de sesión

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String get rol => _currentUser?['rol'] ?? '';
  bool get isAdmin => rol == 'Administrador';
  bool get isSecretaria => rol == 'Secretaria';
  String get idSecretario => _currentUser?['id_secretario'] ?? '01';
  String get sucursalOrigen => _currentUser?['sucursal_origen'] ?? 'AYS';
  String? get sucursalActual => _sucursalActual;

  /// Restaura la sesión desde SharedPreferences si existe
  Future<bool> restoreSessionFromPreferences() async {
    try {
      if (PreferencesManager().isAuthenticated()) {
        final username = PreferencesManager().getUsername();
        final userId = PreferencesManager().getUserId();
        final role = PreferencesManager().getUserRole();
        final idSecretario = PreferencesManager().getIdSecretario();
        final sucursalOrigen = PreferencesManager().getSucursalOrigen();
        final sucursalActual = PreferencesManager().getSucursalActual();

        if (username != null && userId != null && role != null) {
          _currentUser = {
            'username': username,
            'id': userId,
            'rol': role,
            'id_secretario': idSecretario,
            'sucursal_origen': sucursalOrigen,
          };
          _isAuthenticated = true;
          _sucursalActual = sucursalActual;
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error al restaurar sesión: $e');
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final user = await AppDatabase.instance.login(username, password);
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        
        // Guardar sesión en SharedPreferences
        await PreferencesManager().saveUserSession(
          username: user['username'],
          password: password,
          userId: user['id'],
          role: user['rol'],
          idSecretario: user['id_secretario'],
          sucursalOrigen: user['sucursal_origen'],
          rememberUser: true, // Mantener sesión activa
        );
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error al iniciar sesión: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _isAuthenticated = false;
    _sucursalActual = null;
    
    // Limpiar sesión de SharedPreferences
    await PreferencesManager().clearUserSession();
    
    notifyListeners();
  }

  void setSucursalActual(String sucursal) {
    _sucursalActual = sucursal;
    // Guardar también en preferencias para persistencia
    PreferencesManager().setSucursalActual(sucursal);
    notifyListeners();
  }

  String get username => _currentUser?['username'] ?? '';
}
