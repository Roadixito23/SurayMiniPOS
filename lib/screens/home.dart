import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../database/caja_database.dart';
import '../models/auth_provider.dart';
import '../database/app_database.dart';
import 'dart:math' as math;
import '../widgets/debug_popup.dart';

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
                  'assets/logocolorposoffice.png',
                  height: 60,
                  width: 60,
                ),
                SizedBox(height: 12),
                Text(
                  'POS OFFICE',
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
                // Sección Principal
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'PRINCIPAL',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                _SidebarMenuItem(
                  icon: Icons.dashboard,
                  label: 'Panel Principal',
                  isActive: true,
                  onTap: () {},
                ),
                _SidebarMenuItem(
                  icon: Icons.schedule,
                  label: 'Horarios',
                  onTap: () => Navigator.pushNamed(context, '/horarios'),
                ),
                _SidebarMenuItem(
                  icon: Icons.attach_money,
                  label: 'Tarifas',
                  onTap: () => Navigator.pushNamed(context, '/tarifas'),
                ),

                SizedBox(height: 8),
                Divider(color: Colors.white24, thickness: 1),

                // Sección de Administración
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (authProvider.isAdmin) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            'ADMINISTRACIÓN',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        _SidebarMenuItem(
                          icon: Icons.people,
                          label: 'Usuarios',
                          onTap: () => Navigator.pushNamed(context, '/usuarios'),
                        ),
                        _SidebarMenuItem(
                          icon: Icons.settings,
                          label: 'Configuración',
                          onTap: () => Navigator.pushNamed(context, '/settings'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Botón de cerrar sesión
          _LogoutButton(),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white24, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del usuario
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authProvider.username,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.badge, size: 12, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      authProvider.rol,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.numbers, size: 12, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      'ID: ${authProvider.idSecretario}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.location_on, size: 12, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      authProvider.sucursalActual ?? 'N/A',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Botón de cerrar sesión
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _handleLogout(context, authProvider);
              },
              icon: Icon(Icons.logout, size: 18),
              label: Text('Cerrar Sesión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthProvider authProvider) async {
    // Verificar si hay cierres pendientes
    final cajaDb = CajaDatabase();
    final ventasPendientes = await cajaDb.getVentasDiarias();
    final tieneCierresPendientes = ventasPendientes.isNotEmpty;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Cerrar Sesión'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Está seguro que desea cerrar sesión?'),
            SizedBox(height: 16),
            if (tieneCierresPendientes) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ADVERTENCIA: Tiene cierres de caja pendientes',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tiene cierres de caja pendientes',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cerrar Sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      authProvider.logout();
      Navigator.of(context).pushReplacementNamed('/login');
    }
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _floatingAnimationController;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String _secretCode = '';
  bool _isFullScreen = false; // Estado de pantalla completa

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _floatingAnimationController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingAnimationController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // Obtener el authProvider para verificar permisos
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Manejar teclas de función F1-F8 y F11
      if (event.logicalKey == LogicalKeyboardKey.f11) {
        // F11: Alternar pantalla completa
        _toggleFullScreen();
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.f1) {
        // F1: Venta de Pasajes
        Navigator.pushNamed(context, '/venta_bus');
        _showShortcutFeedback('Venta de Pasajes', Icons.airline_seat_recline_normal, Colors.blue);
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.f2) {
        // F2: Venta de Carga
        Navigator.pushNamed(context, '/venta_cargo');
        _showShortcutFeedback('Venta de Carga', Icons.inventory, Colors.purple);
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.f3) {
        // F3: Historial de Carga
        Navigator.pushNamed(context, '/cargo_history');
        _showShortcutFeedback('Historial de Carga', Icons.history, Colors.orange);
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.f4) {
        // F4: Cierre de Caja
        Navigator.pushNamed(context, '/cierre_caja');
        _showShortcutFeedback('Cierre de Caja', Icons.calculate, Colors.green.shade600);
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.f5) {
        // F5: Gestión de Datos
        Navigator.pushNamed(context, '/data_management');
        _showShortcutFeedback('Gestión de Datos', Icons.storage, Colors.indigo);
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.f6) {
        // F6: Gestión de Usuarios (solo admin)
        if (authProvider.isAdmin) {
          Navigator.pushNamed(context, '/usuarios');
          _showShortcutFeedback('Gestión de Usuarios', Icons.people, Colors.deepPurple);
        } else {
          _showShortcutFeedback('Acceso denegado - Solo administradores', Icons.lock, Colors.red);
        }
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.f7) {
        // F7: Estadísticas
        Navigator.pushNamed(context, '/estadisticas');
        _showShortcutFeedback('Estadísticas', Icons.analytics, Colors.teal);
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.f8) {
        // F8: Anular Venta (solo admin)
        if (authProvider.isAdmin) {
          Navigator.pushNamed(context, '/anular_venta');
          _showShortcutFeedback('Anular Venta', Icons.cancel, Colors.red.shade600);
        } else {
          _showShortcutFeedback('Acceso denegado - Solo administradores', Icons.lock, Colors.red);
        }
        return;
      }

      // Manejar códigos secretos (administrador y debug)
      final key = event.character?.toLowerCase();
      if (key != null && key.length == 1) {
        setState(() {
          _secretCode += key;
          // Mantener solo los últimos 13 caracteres (longitud de "administrador")
          if (_secretCode.length > 13) {
            _secretCode = _secretCode.substring(_secretCode.length - 13);
          }

          // Verificar si se escribió "administrador" para ir a settings
          if (_secretCode.contains('administrador')) {
            Navigator.pushNamed(context, '/settings');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Acceso a configuración'),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                duration: Duration(seconds: 2),
              ),
            );
            _secretCode = '';
          }

          // Verificar si se escribió "debug" para abrir el panel de desarrollo
          if (_secretCode.contains('debug')) {
            DebugPopup.show(context);
            _secretCode = '';
          }
        });
      }
    }
  }

  // Método para alternar pantalla completa
  Future<void> _toggleFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      setState(() {
        _isFullScreen = !_isFullScreen;
      });

      if (_isFullScreen) {
        await windowManager.setFullScreen(true);
        _showShortcutFeedback('Modo pantalla completa activado', Icons.fullscreen, Colors.blue);
      } else {
        await windowManager.setFullScreen(false);
        _showShortcutFeedback('Modo pantalla completa desactivado', Icons.fullscreen_exit, Colors.blue);
      }
    }
  }

  // Método para mostrar feedback visual de atajos
  void _showShortcutFeedback(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: color,
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }

  // Método para mostrar el diálogo de ayuda de atajos
  void _showKeyboardShortcutsHelp() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 700,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.keyboard,
                      color: Colors.blue.shade700,
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atajos de Teclado',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          'Accede rápidamente a las funciones del sistema',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Divider(),
              SizedBox(height: 16),

              // Lista de atajos
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildShortcutCategory('Navegación Principal', [
                        _buildShortcutItem('F1', 'Venta de Pasajes', Icons.airline_seat_recline_normal, Colors.blue),
                        _buildShortcutItem('F2', 'Venta de Carga', Icons.inventory, Colors.purple),
                        _buildShortcutItem('F3', 'Historial de Carga', Icons.history, Colors.orange),
                        _buildShortcutItem('F7', 'Estadísticas', Icons.analytics, Colors.teal),
                      ]),
                      SizedBox(height: 16),
                      _buildShortcutCategory('Administración', [
                        _buildShortcutItem('F4', 'Cierre de Caja', Icons.calculate, Colors.green),
                        _buildShortcutItem('F5', 'Gestión de Datos', Icons.storage, Colors.indigo),
                        _buildShortcutItem('F6', 'Gestión de Usuarios (Admin)', Icons.people, Colors.deepPurple),
                        _buildShortcutItem('F8', 'Anular Venta (Admin)', Icons.cancel, Colors.red),
                      ]),
                      SizedBox(height: 16),
                      _buildShortcutCategory('Sistema', [
                        _buildShortcutItem('F11', 'Pantalla Completa', Icons.fullscreen, Colors.blue.shade700),
                      ]),
                      SizedBox(height: 16),
                      _buildShortcutCategory('Códigos Especiales', [
                        _buildShortcutItem('administrador', 'Acceso a Configuración', Icons.settings, Colors.green),
                        _buildShortcutItem('debug', 'Abrir Panel de Desarrollo', Icons.bug_report, Colors.orange),
                      ]),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 12),

              // Pie del diálogo
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Los atajos marcados con (Admin) solo están disponibles para administradores',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutCategory(String title, List<Widget> shortcuts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        ...shortcuts,
      ],
    );
  }

  Widget _buildShortcutItem(String key, String description, IconData icon, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              key,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ),
          SizedBox(width: 16),
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      autofocus: true,
      child: Container(
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
        child: Stack(
          children: [
            Column(
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
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final authProvider = Provider.of<AuthProvider>(context);
                                    return _ActionCard(
                                      icon: Icons.cancel,
                                      title: 'Anular Venta',
                                      description: authProvider.isAdmin
                                          ? 'Anular ventas registradas'
                                          : 'Solo administradores',
                                      color: authProvider.isAdmin ? Colors.red.shade600 : Colors.grey,
                                      shortcut: 'F8',
                                      onTap: authProvider.isAdmin
                                          ? () => Navigator.pushNamed(context, '/anular_venta')
                                          : () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Solo los administradores pueden anular ventas'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
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

            // Botón flotante de ayuda de atajos (siempre visible)
            Positioned(
              bottom: 20,
              left: 20,
              child: FloatingActionButton.extended(
                onPressed: _showKeyboardShortcutsHelp,
                backgroundColor: Colors.blue.shade700,
                icon: Icon(Icons.keyboard, color: Colors.white),
                label: Text(
                  'Atajos de Teclado',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                heroTag: 'keyboard_shortcuts',
              ),
            ),
          ],
        ),
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

class _ActionCardState extends State<_ActionCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0)..scale(_isHovered ? 1.02 : 1.0),
        child: Card(
          elevation: _isHovered ? 16 : 4,
          shadowColor: widget.color.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _isHovered ? widget.color.withOpacity(0.3) : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: widget.color.withOpacity(0.1),
            highlightColor: widget.color.withOpacity(0.05),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _isHovered ? LinearGradient(
                  colors: [
                    widget.color.withOpacity(0.08),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ) : null,
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(_isHovered ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _isHovered ? [
                                BoxShadow(
                                  color: widget.color.withOpacity(0.3 * _pulseController.value),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ] : [],
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.color,
                              size: 28,
                            ),
                          );
                        },
                      ),
                      Spacer(),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isHovered ? widget.color : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _isHovered ? [
                            BoxShadow(
                              color: widget.color.withOpacity(0.3),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ] : [],
                        ),
                        child: Text(
                          widget.shortcut,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isHovered ? Colors.white : Colors.grey.shade700,
                            letterSpacing: 0.5,
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