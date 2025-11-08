import 'package:flutter/material.dart';
import 'responsive_helper.dart';

/// Scaffold responsive que muestra navegación lateral permanente en desktop
class ResponsiveScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showDrawer;
  final String? currentRoute;

  const ResponsiveScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.actions,
    this.showDrawer = true,
    this.currentRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final showPersistentDrawer = ResponsiveHelper.shouldShowPersistentDrawer(context) && showDrawer;

    if (showPersistentDrawer) {
      // Layout para desktop con drawer permanente
      return Scaffold(
        body: Row(
          children: [
            // Drawer permanente
            Container(
              width: ResponsiveHelper.getDrawerWidth(context),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(2, 0),
                  ),
                ],
              ),
              child: _buildDrawerContent(context, isPersistent: true),
            ),
            // Contenido principal
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(title),
                  centerTitle: true,
                  automaticallyImplyLeading: false, // No mostrar botón de drawer
                  actions: actions,
                ),
                body: body,
              ),
            ),
          ],
        ),
      );
    } else {
      // Layout para móvil con drawer deslizable
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
          actions: actions,
        ),
        drawer: showDrawer ? Drawer(
          child: _buildDrawerContent(context, isPersistent: false),
        ) : null,
        body: body,
      );
    }
  }

  Widget _buildDrawerContent(BuildContext context, {required bool isPersistent}) {
    return Container(
      color: isPersistent ? Theme.of(context).primaryColor : null,
      child: Column(
        children: [
          // Header del drawer
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveHelper.getResponsiveSpacing(context, 32),
              horizontal: ResponsiveHelper.getResponsiveSpacing(context, 16),
            ),
            decoration: BoxDecoration(
              color: isPersistent ? Theme.of(context).primaryColor.withOpacity(0.9) : Theme.of(context).primaryColor,
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/logocolorminipos.png',
                  height: ResponsiveHelper.getIconSize(context, 80),
                  width: ResponsiveHelper.getIconSize(context, 80),
                ),
                SizedBox(height: 16),
                Text(
                  'Suray Mini POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sistema de Ventas',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                  ),
                ),
              ],
            ),
          ),

          // Menú de navegación
          Expanded(
            child: Container(
              color: isPersistent ? Theme.of(context).primaryColor.withOpacity(0.95) : null,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.home,
                    title: 'Inicio',
                    route: '/home',
                    isPersistent: isPersistent,
                  ),
                  Divider(color: Colors.white.withOpacity(0.2), height: 1),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.airline_seat_recline_normal,
                    title: 'Venta de Pasajes',
                    route: '/venta_bus',
                    isPersistent: isPersistent,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.inventory,
                    title: 'Venta de Carga',
                    route: '/venta_cargo',
                    isPersistent: isPersistent,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.history,
                    title: 'Historial de Carga',
                    route: '/cargo_history',
                    isPersistent: isPersistent,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.schedule,
                    title: 'Horarios',
                    route: '/horarios',
                    isPersistent: isPersistent,
                  ),
                  Divider(color: Colors.white.withOpacity(0.2), height: 1),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.calculate,
                    title: 'Cierre de Caja',
                    route: '/cierre_caja',
                    isPersistent: isPersistent,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.storage,
                    title: 'Gestión de Datos',
                    route: '/data_management',
                    isPersistent: isPersistent,
                  ),
                  Divider(color: Colors.white.withOpacity(0.2), height: 1),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings,
                    title: 'Configuración',
                    route: '/settings',
                    isPersistent: isPersistent,
                  ),
                ],
              ),
            ),
          ),

          // Footer
          if (isPersistent)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.8),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                'v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    required bool isPersistent,
  }) {
    final isSelected = currentRoute == route;
    final textColor = isPersistent ? Colors.white : null;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
          ? (isPersistent ? Colors.white : Theme.of(context).primaryColor)
          : (isPersistent ? Colors.white.withOpacity(0.8) : null),
        size: ResponsiveHelper.getIconSize(context, 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
            ? (isPersistent ? Colors.white : Theme.of(context).primaryColor)
            : (isPersistent ? Colors.white.withOpacity(0.9) : null),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
        ),
      ),
      selected: isSelected,
      selectedTileColor: isPersistent
        ? Colors.white.withOpacity(0.15)
        : Theme.of(context).primaryColor.withOpacity(0.1),
      onTap: () {
        if (!isPersistent) {
          Navigator.pop(context); // Cerrar drawer en móvil
        }
        if (currentRoute != route) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }
}
