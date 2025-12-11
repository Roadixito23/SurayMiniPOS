import 'dart:async';
import 'package:flutter/foundation.dart';
import 'cloud_api_service.dart';
import '../database/app_database.dart';

/// Servicio para sincronización automática en background
class AutoSyncService {
  static AutoSyncService? _instance;
  Timer? _syncTimer;
  bool _isRunning = false;
  int _intervalMinutes = 5; // Intervalo por defecto: 5 minutos

  AutoSyncService._();

  static AutoSyncService get instance {
    _instance ??= AutoSyncService._();
    return _instance!;
  }

  /// Inicia el servicio de sincronización automática
  void start({int intervalMinutes = 5}) {
    if (_isRunning) {
      debugPrint('AutoSyncService ya está en ejecución');
      return;
    }

    _intervalMinutes = intervalMinutes;
    _isRunning = true;

    debugPrint('AutoSyncService iniciado con intervalo de $_intervalMinutes minutos');

    // Ejecutar sincronización inmediata
    _performSync();

    // Configurar timer periódico
    _syncTimer = Timer.periodic(
      Duration(minutes: _intervalMinutes),
      (timer) => _performSync(),
    );
  }

  /// Detiene el servicio de sincronización automática
  void stop() {
    if (!_isRunning) {
      return;
    }

    _syncTimer?.cancel();
    _syncTimer = null;
    _isRunning = false;

    debugPrint('AutoSyncService detenido');
  }

  /// Realiza la sincronización automática
  Future<void> _performSync() async {
    try {
      // Verificar si el modo solo offline está activado
      final soloOffline = await CloudApiService.isModoSoloOffline();
      if (soloOffline) {
        debugPrint('[AutoSync] Modo solo offline activado - sincronización omitida');
        return;
      }

      // Verificar conexión
      final isConnected = await CloudApiService.verificarConexion();
      if (!isConnected) {
        debugPrint('[AutoSync] Sin conexión - sincronización omitida');
        return;
      }

      // Verificar si hay datos pendientes de sincronizar
      final db = AppDatabase.instance;
      final ventasPendientes = await db.obtenerVentasNoSincronizadas();
      final cierresPendientes = await db.obtenerCierresNoSincronizados();

      if (ventasPendientes.isEmpty && cierresPendientes.isEmpty) {
        debugPrint('[AutoSync] No hay datos pendientes de sincronizar');
        return;
      }

      debugPrint('[AutoSync] Iniciando sincronización automática...');
      debugPrint('[AutoSync] Ventas pendientes: ${ventasPendientes.length}');
      debugPrint('[AutoSync] Cierres pendientes: ${cierresPendientes.length}');

      // Sincronizar ventas
      if (ventasPendientes.isNotEmpty) {
        final ventasResult = await CloudApiService.sincronizarVentasLocal();
        debugPrint('[AutoSync] Ventas sincronizadas: ${ventasResult['enviados']} de ${ventasPendientes.length}');

        if (ventasResult['errores'] > 0) {
          debugPrint('[AutoSync] Errores en ventas: ${ventasResult['errores']}');
        }
      }

      // Sincronizar cierres
      if (cierresPendientes.isNotEmpty) {
        final cierresResult = await CloudApiService.sincronizarCierresLocal();
        debugPrint('[AutoSync] Cierres sincronizados: ${cierresResult['enviados']} de ${cierresPendientes.length}');

        if (cierresResult['errores'] > 0) {
          debugPrint('[AutoSync] Errores en cierres: ${cierresResult['errores']}');
        }
      }

      debugPrint('[AutoSync] Sincronización automática completada');
    } catch (e) {
      debugPrint('[AutoSync] Error durante la sincronización automática: $e');
    }
  }

  /// Fuerza una sincronización inmediata
  Future<void> syncNow() async {
    if (!_isRunning) {
      debugPrint('[AutoSync] El servicio no está en ejecución');
      return;
    }

    await _performSync();
  }

  /// Verifica si el servicio está en ejecución
  bool get isRunning => _isRunning;

  /// Obtiene el intervalo actual en minutos
  int get intervalMinutes => _intervalMinutes;

  /// Cambia el intervalo de sincronización (reinicia el timer)
  void setInterval(int minutes) {
    if (minutes < 1) {
      debugPrint('[AutoSync] Intervalo mínimo: 1 minuto');
      return;
    }

    _intervalMinutes = minutes;

    if (_isRunning) {
      // Reiniciar el timer con el nuevo intervalo
      stop();
      start(intervalMinutes: _intervalMinutes);
      debugPrint('[AutoSync] Intervalo actualizado a $_intervalMinutes minutos');
    }
  }
}
