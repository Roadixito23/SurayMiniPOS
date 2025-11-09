import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/auth_provider.dart';
import 'dart:math' as math;

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar con navegación
          _Sidebar(),
          // Contenido principal
          Expanded(
            child: HomePage(),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo y título
          Container(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset(
                  'assets/logocolorminipos.png',
                  height: 60,
                  width: 60,
                ),
                SizedBox(height: 12),
                Text(
                  'POSBUS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sistema de Gestión',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white24, thickness: 1),
          // Menú de navegación
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8),
              children: [
                _SidebarMenuItem(
                  icon: Icons.home,
                  label: 'Inicio',
                  isActive: true,
                  onTap: () {},
                ),
                _SidebarMenuItem(
                  icon: Icons.schedule,
                  label: 'Horarios',
                  onTap: () => Navigator.pushNamed(context, '/horarios'),
                ),
                Divider(color: Colors.white24, height: 24, indent: 16, endIndent: 16),
                _SidebarMenuItem(
                  icon: Icons.settings,
                  label: 'Configuración',
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarMenuItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<_SidebarMenuItem> createState() => _SidebarMenuItemState();
}

class _SidebarMenuItemState extends State<_SidebarMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: widget.isActive
              ? Colors.white.withOpacity(0.15)
              : _isHovered
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            widget.icon,
            color: Colors.white,
            size: 22,
          ),
          title: Text(
            widget.label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: widget.onTap,
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50.withOpacity(0.3),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // Barra superior moderna
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.dashboard,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panel Principal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      'Bienvenido al sistema',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      SizedBox(width: 8),
                      Text(
                        DateTime.now().toString().substring(0, 16),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contenido principal con scrollbar fijo
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 8,
              radius: Radius.circular(4),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.all(32),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sección de ventas
                  _SectionHeader(
                    title: 'Ventas',
                    icon: Icons.shopping_cart,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.airline_seat_recline_normal,
                          title: 'Venta de Pasajes',
                          description: 'Registrar venta de boletos de bus',
                          color: Colors.blue,
                          shortcut: 'F1',
                          onTap: () => Navigator.pushNamed(context, '/venta_bus'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.inventory,
                          title: 'Venta de Carga',
                          description: 'Registrar envío de encomiendas',
                          color: Colors.purple,
                          shortcut: 'F2',
                          onTap: () => Navigator.pushNamed(context, '/venta_cargo'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Sección de consultas
                  _SectionHeader(
                    title: 'Consultas y Análisis',
                    icon: Icons.search,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.history,
                          title: 'Historial de Carga',
                          description: 'Consultar envíos registrados',
                          color: Colors.orange,
                          shortcut: 'F3',
                          onTap: () => Navigator.pushNamed(context, '/cargo_history'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.analytics,
                          title: 'Estadísticas',
                          description: 'Ver análisis y reportes del sistema',
                          color: Colors.teal,
                          shortcut: 'F7',
                          onTap: () => Navigator.pushNamed(context, '/estadisticas'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Sección de administración
                  _SectionHeader(
                    title: 'Administración',
                    icon: Icons.admin_panel_settings,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.calculate,
                          title: 'Cierre de Caja',
                          description: 'Realizar cuadre de caja diario',
                          color: Colors.green.shade600,
                          shortcut: 'F4',
                          onTap: () => Navigator.pushNamed(context, '/cierre_caja'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.storage,
                          title: 'Gestión de Datos',
                          description: 'Administrar información del sistema',
                          color: Colors.indigo,
                          shortcut: 'F5',
                          onTap: () => Navigator.pushNamed(context, '/data_management'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final authProvider = Provider.of<AuthProvider>(context);
                            return _ActionCard(
                              icon: Icons.people,
                              title: 'Gestión de Usuarios',
                              description: authProvider.isAdmin
                                  ? 'Administrar usuarios y permisos'
                                  : 'Solo administradores',
                              color: authProvider.isAdmin ? Colors.deepPurple : Colors.grey,
                              shortcut: 'F6',
                              onTap: authProvider.isAdmin
                                  ? () => Navigator.pushNamed(context, '/usuarios')
                                  : () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Solo los administradores pueden acceder a esta sección'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    },
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(child: SizedBox()),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Información del sistema con animación
                  FadeTransition(
                    opacity: _animationController,
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.blue.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
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
                              color: Colors.blue.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.cloud_done,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sistema de Respaldo Activo',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tus datos están protegidos automáticamente',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 24),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String shortcut;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.shortcut,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        child: Card(
          elevation: _isHovered ? 8 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.color,
                          size: 28,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.shortcut,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}