import 'dart:io';

import 'package:flutter/material.dart';
import 'splash.dart';
import 'home.dart';
import 'venta_bus_screen.dart';
import 'venta_cargo_screen.dart';
import 'admin_comprobantes_screen.dart';
import 'cargo_history_screen.dart';
import 'cierre_caja_screen.dart';
import 'data_management_screen.dart';
import 'horario_screen.dart'; // Nueva importación para la pantalla de horarios
import 'settings_screen.dart'; // Nueva importación para la pantalla de configuración
import 'comprobante.dart';
import 'caja_database.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar el gestor de comprobantes al inicio de la aplicación
  final comprobanteManager = ComprobanteManager();
  await comprobanteManager.initialize();

  // Inicializar la base de datos de caja con el nuevo sistema de persistencia
  final cajaDatabase = CajaDatabase();
  await cajaDatabase.initialize();

  // Verificar y crear los directorios necesarios
  await _ensureDirectoriesExist();

  runApp(MyApp());
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
      title: 'Suray Mini POS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue.shade700,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => SplashScreen(),
        '/home': (_) => HomeScreen(),
        '/venta_bus': (_) => VentaBusScreen(),
        '/venta_cargo': (_) => VentaCargoScreen(),
        '/admin_comprobantes': (_) => AdminComprobantesScreen(),
        '/cargo_history': (_) => CargoHistoryScreen(),
        '/cierre_caja': (_) => CierreCajaScreen(),
        '/data_management': (_) => DataManagementScreen(),
        '/horarios': (_) => HorarioScreen(), // Nueva ruta para la pantalla de horarios
        '/settings': (_) => SettingsScreen(), // Nueva ruta para la pantalla de configuración
      },
    );
  }
}