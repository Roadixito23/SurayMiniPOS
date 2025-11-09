import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../database/app_database.dart';
import '../database/caja_database.dart';

class EstadisticasScreen extends StatefulWidget {
  @override
  _EstadisticasScreenState createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  int _totalUsuarios = 0;
  int _usuariosActivos = 0;
  int _ventasHoy = 0;
  double _totalVentasHoy = 0;
  int _cargasHoy = 0;
  double _totalCargasHoy = 0;
  String _origenActual = 'AYS';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _cargarEstadisticas();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _isLoading = true);

    try {
      // Cargar estadísticas de usuarios
      final usuarios = await AppDatabase.instance.obtenerUsuarios();
      _totalUsuarios = usuarios.length;
      _usuariosActivos = usuarios.where((u) => u['activo'] == 1).length;

      // Cargar origen actual
      final origen = await AppDatabase.instance.getConfiguracion('origen');
      _origenActual = origen ?? 'AYS';

      // Cargar estadísticas de ventas de hoy
      await _cargarVentasHoy();

      _animationController.forward();
    } catch (e) {
      print('Error cargando estadísticas: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarVentasHoy() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final ventasFile = File('${directory.path}/ventas_diarias.json');

      if (await ventasFile.exists()) {
        String content = await ventasFile.readAsString();
        Map<String, dynamic> data = json.decode(content);
        List<dynamic> ventas = data['ventas'] ?? [];

        String hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

        // Filtrar ventas de hoy
        var ventasHoy = ventas.where((v) => v['fecha'] == hoy).toList();

        _ventasHoy = ventasHoy.where((v) => v['tipo'] == 'bus').length;
        _totalVentasHoy = ventasHoy
            .where((v) => v['tipo'] == 'bus')
            .fold(0.0, (sum, v) => sum + (v['valor'] ?? 0));

        _cargasHoy = ventasHoy.where((v) => v['tipo'] == 'cargo').length;
        _totalCargasHoy = ventasHoy
            .where((v) => v['tipo'] == 'cargo')
            .fold(0.0, (sum, v) => sum + (v['valor'] ?? 0));
      }
    } catch (e) {
      print('Error cargando ventas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estadísticas del Sistema'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarEstadisticas,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue.shade50,
                      Colors.white,
                    ],
                  ),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 8,
                  radius: Radius.circular(4),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado
                        _buildHeader(),
                        SizedBox(height: 24),

                        // Resumen general
                        Text(
                          'Resumen General',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Tarjetas de estadísticas
                        _buildStatsGrid(),

                        SizedBox(height: 32),

                        // Ventas de hoy
                        Text(
                          'Ventas de Hoy',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 16),

                        _buildVentasHoyGrid(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics,
              size: 40,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel de Estadísticas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Origen: ${_origenActual == "AYS" ? "Aysén" : "Coyhaique"}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            title: 'Total Usuarios',
            value: _totalUsuarios.toString(),
            color: Colors.blue,
            delay: 0,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.person_outline,
            title: 'Usuarios Activos',
            value: _usuariosActivos.toString(),
            color: Colors.green,
            delay: 100,
          ),
        ),
      ],
    );
  }

  Widget _buildVentasHoyGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.airline_seat_recline_normal,
                title: 'Pasajes Vendidos',
                value: _ventasHoy.toString(),
                color: Colors.purple,
                delay: 200,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.attach_money,
                title: 'Total Pasajes',
                value: NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                    .format(_totalVentasHoy),
                color: Colors.teal,
                delay: 300,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.inventory,
                title: 'Cargas Registradas',
                value: _cargasHoy.toString(),
                color: Colors.orange,
                delay: 400,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.attach_money,
                title: 'Total Cargas',
                value: NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                    .format(_totalCargasHoy),
                color: Colors.indigo,
                delay: 500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required int delay,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, double opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.shade50, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: color,
                ),
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
