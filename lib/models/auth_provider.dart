import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  bool _isAuthenticated = false;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String get rol => _currentUser?['rol'] ?? '';
  bool get isAdmin => rol == 'Administrador';
  bool get isSecretaria => rol == 'Secretaria';

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
    notifyListeners();
  }

  String get username => _currentUser?['username'] ?? '';
}
