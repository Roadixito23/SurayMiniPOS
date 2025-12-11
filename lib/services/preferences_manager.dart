import 'package:shared_preferences/shared_preferences.dart';

/// Gestor centralizado de SharedPreferences para persistencia de datos
class PreferencesManager {
  static final PreferencesManager _instance = PreferencesManager._internal();
  static SharedPreferences? _prefs;

  // Claves de preferencias
  static const String _keyUsername = 'username';
  static const String _keyPassword = 'password';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyIdSecretario = 'id_secretario';
  static const String _keySucursalOrigen = 'sucursal_origen';
  static const String _keySucursalActual = 'sucursal_actual';
  static const String _keyIsAuthenticated = 'is_authenticated';
  static const String _keyRememberUser = 'remember_user';
  static const String _keyLastLoginTime = 'last_login_time';
  static const String _keyReceiptNumber = 'receipt_number';
  static const String _keyOriginConfig = 'config_origen';

  factory PreferencesManager() {
    return _instance;
  }

  PreferencesManager._internal();

  /// Inicializa el gestor de preferencias
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ============ MÉTODOS DE SESIÓN DE USUARIO ============

  /// Guarda las credenciales y datos del usuario tras login exitoso
  Future<void> saveUserSession({
    required String username,
    required String password,
    required int userId,
    required String role,
    required String idSecretario,
    required String sucursalOrigen,
    bool rememberUser = false,
  }) async {
    if (_prefs == null) await initialize();
    
    await Future.wait([
      _prefs!.setString(_keyUsername, username),
      _prefs!.setString(_keyPassword, password),
      _prefs!.setInt(_keyUserId, userId),
      _prefs!.setString(_keyUserRole, role),
      _prefs!.setString(_keyIdSecretario, idSecretario),
      _prefs!.setString(_keySucursalOrigen, sucursalOrigen),
      _prefs!.setBool(_keyIsAuthenticated, true),
      _prefs!.setBool(_keyRememberUser, rememberUser),
      _prefs!.setString(_keyLastLoginTime, DateTime.now().toIso8601String()),
    ]);
  }

  /// Obtiene el nombre de usuario guardado
  String? getUsername() => _prefs?.getString(_keyUsername);

  /// Obtiene la contraseña guardada (si remember_user está activo)
  String? getPassword() => _prefs?.getString(_keyPassword);

  /// Obtiene el ID del usuario
  int? getUserId() => _prefs?.getInt(_keyUserId);

  /// Obtiene el rol del usuario
  String? getUserRole() => _prefs?.getString(_keyUserRole);

  /// Obtiene el ID de secretario
  String? getIdSecretario() => _prefs?.getString(_keyIdSecretario);

  /// Obtiene la sucursal de origen
  String? getSucursalOrigen() => _prefs?.getString(_keySucursalOrigen);

  /// Verifica si existe una sesión autenticada
  bool isAuthenticated() => _prefs?.getBool(_keyIsAuthenticated) ?? false;

  /// Obtiene si el usuario marcó "recordar contraseña"
  bool isRememberUser() => _prefs?.getBool(_keyRememberUser) ?? false;

  /// Obtiene la hora del último login
  DateTime? getLastLoginTime() {
    final timeStr = _prefs?.getString(_keyLastLoginTime);
    if (timeStr != null) {
      try {
        return DateTime.parse(timeStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Limpia la sesión del usuario (logout)
  Future<void> clearUserSession() async {
    if (_prefs == null) return;
    await Future.wait([
      _prefs!.remove(_keyUsername),
      _prefs!.remove(_keyPassword),
      _prefs!.remove(_keyUserId),
      _prefs!.remove(_keyUserRole),
      _prefs!.remove(_keyIdSecretario),
      _prefs!.remove(_keySucursalOrigen),
      _prefs!.remove(_keyIsAuthenticated),
      _prefs!.remove(_keyLastLoginTime),
      _prefs!.remove(_keySucursalActual),
    ]);
  }

  // ============ MÉTODOS DE SUCURSAL ============

  /// Guarda la sucursal seleccionada en la sesión actual
  Future<void> setSucursalActual(String sucursal) async {
    await _prefs?.setString(_keySucursalActual, sucursal);
  }

  /// Obtiene la sucursal actual seleccionada
  String? getSucursalActual() => _prefs?.getString(_keySucursalActual);

  // ============ MÉTODOS DE CONFIGURACIÓN ============

  /// Guarda el número de comprobante
  Future<void> setReceiptNumber(int number) async {
    await _prefs?.setInt(_keyReceiptNumber, number);
  }

  /// Obtiene el número de comprobante
  int getReceiptNumber() => _prefs?.getInt(_keyReceiptNumber) ?? 1;

  /// Guarda la configuración de origen
  Future<void> setOriginConfig(String origin) async {
    await _prefs?.setString(_keyOriginConfig, origin);
  }

  /// Obtiene la configuración de origen
  String? getOriginConfig() => _prefs?.getString(_keyOriginConfig);

  // ============ MÉTODOS GENERALES ============

  /// Guarda una preferencia genérica de tipo String
  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  /// Obtiene una preferencia genérica de tipo String
  String? getString(String key) => _prefs?.getString(key);

  /// Guarda una preferencia genérica de tipo int
  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  /// Obtiene una preferencia genérica de tipo int
  int? getInt(String key) => _prefs?.getInt(key);

  /// Guarda una preferencia genérica de tipo bool
  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// Obtiene una preferencia genérica de tipo bool
  bool? getBool(String key) => _prefs?.getBool(key);

  /// Guarda una preferencia genérica de tipo double
  Future<void> setDouble(String key, double value) async {
    await _prefs?.setDouble(key, value);
  }

  /// Obtiene una preferencia genérica de tipo double
  double? getDouble(String key) => _prefs?.getDouble(key);

  /// Elimina una preferencia específica
  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  /// Limpia todas las preferencias
  Future<void> clear() async {
    await _prefs?.clear();
  }

  /// Obtiene todas las claves guardadas
  Set<String> getKeys() => _prefs?.getKeys() ?? {};
}
