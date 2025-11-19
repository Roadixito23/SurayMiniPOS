import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestor de códigos de administrador para anulaciones
class AdminCodeManager {
  static const String _codeKey = 'admin_cancellation_code';
  static const String _generatedAtKey = 'admin_code_generated_at';

  static AdminCodeManager? _instance;

  factory AdminCodeManager() {
    _instance ??= AdminCodeManager._internal();
    return _instance!;
  }

  AdminCodeManager._internal();

  /// Genera un código aleatorio de 5 dígitos
  Future<String> generateNewCode() async {
    final random = Random();
    final code = (10000 + random.nextInt(90000)).toString();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeKey, code);
    await prefs.setString(_generatedAtKey, DateTime.now().toIso8601String());

    return code;
  }

  /// Obtiene el código actual (si existe)
  Future<String?> getCurrentCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_codeKey);
  }

  /// Obtiene la fecha de generación del código actual
  Future<DateTime?> getCodeGeneratedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_generatedAtKey);
    if (dateStr != null) {
      return DateTime.parse(dateStr);
    }
    return null;
  }

  /// Verifica si un código es válido
  Future<bool> verifyCode(String inputCode) async {
    final currentCode = await getCurrentCode();
    if (currentCode == null) return false;
    return inputCode.trim() == currentCode;
  }

  /// Elimina el código actual
  Future<void> clearCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_codeKey);
    await prefs.remove(_generatedAtKey);
  }

  /// Verifica si hay un código activo
  Future<bool> hasActiveCode() async {
    final code = await getCurrentCode();
    return code != null;
  }
}
