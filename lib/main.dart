import 'package:flutter/material.dart';
import 'splash.dart';
import 'home.dart';
import 'venta_bus_screen.dart';
import 'venta_cargo_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Aplicación Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/home': (context) => HomeScreen(),
        '/venta_bus': (context) => VentaBusScreen(),
        '/venta_cargo': (context) => VentaCargoScreen(),
      },
    );
  }
}