import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/splash.dart';
import 'screens/login_screen.dart';
import 'screens/home.dart';
import 'screens/venta_bus_screen.dart';
import 'screens/venta_cargo_screen.dart';
import 'screens/admin_comprobantes_screen.dart';
import 'screens/cargo_history_screen.dart';
import 'screens/cierre_caja_screen.dart';
import 'screens/data_management_screen.dart';
import 'screens/horario_screen.dart'; // Nueva importación para la pantalla de horarios
import 'screens/settings_screen.dart'; // Nueva importación para la pantalla de configuración
import 'screens/tarifas_screen.dart'; // Nueva importación para la pantalla de tarifas
import 'screens/usuarios_screen.dart'; // Nueva importación para la pantalla de usuarios
import 'screens/estadisticas_screen.dart'; // Nueva importación para la pantalla de estadísticas
import 'screens/anular_venta_screen.dart'; // Nueva importación para anular ventas
import 'screens/gestion_anulaciones_screen.dart'; // Nueva importación para gestión de anulaciones
import 'screens/sincronizacion_screen.dart'; // Nueva importación para sincronización cloud
import 'models/comprobante.dart';
import 'models/auth_provider.dart';
import 'models/server_status_provider.dart';
import 'database/caja_database.dart';
import 'database/app_database.dart';
import 'services/preferences_manager.dart';
import 'services/auto_sync_service.dart'; // Servicio de sincronización automática
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar SharedPreferences para persistencia de datos
  await PreferencesManager.initialize();

  // Inicializar window_manager para funciones de ventana (pantalla completa, etc.)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(1024, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Inicializar sqflite para plataformas de escritorio (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Inicializar el gestor de comprobantes al inicio de la aplicación
  final comprobanteManager = ComprobanteManager();
  await comprobanteManager.initialize();

  // Inicializar la base de datos de caja con el nuevo sistema de persistencia
  final cajaDatabase = CajaDatabase();
  await cajaDatabase.initialize();

  // Inicializar la base de datos de la aplicación (usuarios, configuración, tarifas, horarios)
  await AppDatabase.instance.database;

  // Verificar y crear los directorios necesarios
  await _ensureDirectoriesExist();

  // Iniciar servicio de sincronización automática en background
  // Se iniciará con intervalo de 5 minutos por defecto
  AutoSyncService.instance.start(intervalMinutes: 5);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ServerStatusProvider()),
      ],
      child: MyApp(),
    ),
  );
}

// Función para asegurar que existan los directorios necesarios
Future<void> _ensureDirectoriesExist() async {
  try {
    final appDir = await getApplicationDocumentsDirectory();

    // Directorio de backups
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    // Directorio de cargo_receipts (usado en cargo_database.dart)
    final cargoDir = Directory('${appDir.path}/cargo_receipts');
    if (!await cargoDir.exists()) {
      await cargoDir.create(recursive: true);
    }
  } catch (e) {
    print('Error al crear directorios: $e');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suray POS OFICINA - Sistema Empresarial',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés
      ],
      locale: const Locale('es', 'ES'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 3,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF1976D2),
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 3,
          centerTitle: true,
        ),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => HomeScreen(),
        '/venta_bus': (_) => VentaBusScreen(),
        '/venta_cargo': (_) => VentaCargoScreen(),
        '/admin_comprobantes': (_) => AdminComprobantesScreen(),
        '/cargo_history': (_) => CargoHistoryScreen(),
        '/cierre_caja': (_) => CierreCajaScreen(),
        '/data_management': (_) => DataManagementScreen(),
        '/horarios': (_) => HorarioScreen(), // Nueva ruta para la pantalla de horarios
        '/settings': (_) => SettingsScreen(), // Nueva ruta para la pantalla de configuración
        '/tarifas': (_) => const TarifasScreen(), // Nueva ruta para la pantalla de tarifas
        '/usuarios': (_) => UsuariosScreen(), // Nueva ruta para la pantalla de usuarios
        '/estadisticas': (_) => EstadisticasScreen(), // Nueva ruta para la pantalla de estadísticas
        '/anular_venta': (_) => AnularVentaScreen(), // Nueva ruta para anular ventas
        '/gestion_anulaciones': (_) => GestionAnulacionesScreen(), // Nueva ruta para gestión de anulaciones
        '/sincronizacion': (_) => const SincronizacionScreen(), // Nueva ruta para sincronización cloud
      },
    );
  }
}