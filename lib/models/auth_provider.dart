import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

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

  Future<bool> login(String username, String password) async {
    try {
      final user = await AppDatabase.instance.login(username, password);
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error al iniciar sesión: $e');
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    _sucursalActual = null;
    notifyListeners();
  }

  void setSucursalActual(String sucursal) {
    _sucursalActual = sucursal;
    notifyListeners();
  }

  String get username => _currentUser?['username'] ?? '';
}
