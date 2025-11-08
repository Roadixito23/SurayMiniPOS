import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'dart:math' as math;
import 'responsive_helper.dart';
import 'responsive_scaffold.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Inicio',
      currentRoute: '/home',
      actions: [
        IconButton(
          icon: Icon(Icons.settings),
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
          tooltip: 'Configuración',
        ),
      ],
      body: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<GlobalKey> _buttonKeys = List.generate(6, (_) => GlobalKey());
  bool _showButtons = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    Future.delayed(Duration(milliseconds: 200), () {
      setState(() {
        _showButtons = true;
      });
      _controller.repeat(); // Animación infinita
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = ResponsiveHelper.getHorizontalPadding(context);
    final verticalPadding = ResponsiveHelper.getVerticalPadding(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.05),
            Colors.white,
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            children: [
          // Logo animado
          Center(
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: Duration(milliseconds: 1500),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                final logoSize = ResponsiveHelper.getIconSize(context, 120.0);
                final imageSize = ResponsiveHelper.getIconSize(context, 80.0);

                return Transform.scale(
                  scale: value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _controller.value * 2 * math.pi,
                            child: Container(
                              height: logoSize,
                              width: logoSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Colors.blue.shade100,
                                    Colors.blue.shade50,
                                    Colors.white,
                                    Colors.blue.shade50,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Hero(
                        tag: 'logo',
                        child: Image.asset(
                          'assets/logocolorminipos.png',
                          height: imageSize,
                          width: imageSize,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 24)),

          // Título con animación
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    'Bienvenido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 30)),

          // Sección Principal - Grid de botones
          _buildSectionTitle('Menú Principal', 300, context),

          // Grid de botones en lugar de lista
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: ResponsiveHelper.getGridColumnCount(context, mobile: 2, tablet: 3, desktop: 4),
            childAspectRatio: ResponsiveHelper.isWideScreen(context) ? 1.2 : 1.3,
            mainAxisSpacing: ResponsiveHelper.getResponsiveSpacing(context, 16),
            crossAxisSpacing: ResponsiveHelper.getResponsiveSpacing(context, 16),
            children: [
              _buildGridMenuButton(
                key: _buttonKeys[0],
                icon: Icons.airline_seat_recline_normal,
                label: 'Venta de Pasajes',
                color: Colors.blue,
                index: 0,
                route: '/venta_bus',
                delay: 400,
              ),
              _buildGridMenuButton(
                key: _buttonKeys[1],
                icon: Icons.inventory,
                label: 'Venta de Carga',
                color: Colors.purple,
                index: 1,
                route: '/venta_cargo',
                delay: 500,
              ),
              _buildGridMenuButton(
                key: _buttonKeys[2],
                icon: Icons.history,
                label: 'Historial de Carga',
                color: Colors.orange,
                index: 2,
                route: '/cargo_history',
                delay: 600,
              ),
              // Nuevo botón de Horario
              _buildGridMenuButton(
                key: _buttonKeys[3],
                icon: Icons.schedule,
                label: 'Horarios',
                color: Colors.teal,
                index: 3,
                route: '/horarios',
                delay: 700,
              ),
            ],
          ),

          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 24)),
          Divider(color: Colors.blue.shade100, thickness: 1),
          _buildSectionTitle('Administración', 600, context),

          // Botones de administración - adaptativo según pantalla
          ResponsiveHelper.isWideScreen(context)
              ? GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: ResponsiveHelper.getGridColumnCount(context, mobile: 2, tablet: 2, desktop: 4),
                  childAspectRatio: ResponsiveHelper.isWideScreen(context) ? 1.2 : 1.3,
                  mainAxisSpacing: ResponsiveHelper.getResponsiveSpacing(context, 16),
                  crossAxisSpacing: ResponsiveHelper.getResponsiveSpacing(context, 16),
                  children: [
                    _buildGridMenuButton(
                      key: _buttonKeys[4],
                      icon: Icons.calculate,
                      label: 'Cierre de Caja',
                      color: Colors.green.shade600,
                      index: 4,
                      route: '/cierre_caja',
                      delay: 800,
                      small: false,
                    ),
                    _buildGridMenuButton(
                      key: _buttonKeys[5],
                      icon: Icons.storage,
                      label: 'Gestión de Datos',
                      color: Colors.indigo,
                      index: 5,
                      route: '/data_management',
                      delay: 900,
                      small: false,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildGridMenuButton(
                        key: _buttonKeys[4],
                        icon: Icons.calculate,
                        label: 'Cierre de Caja',
                        color: Colors.green.shade600,
                        index: 4,
                        route: '/cierre_caja',
                        delay: 800,
                        small: true,
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                    Expanded(
                      child: _buildGridMenuButton(
                        key: _buttonKeys[5],
                        icon: Icons.storage,
                        label: 'Gestión de Datos',
                        color: Colors.indigo,
                        index: 5,
                        route: '/data_management',
                        delay: 900,
                        small: true,
                      ),
                    ),
                  ],
                ),

          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 30)),

          // Sección de información
          AnimatedOpacity(
            opacity: _showButtons ? 1.0 : 0.0,
            duration: Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 800),
              curve: Curves.easeOutQuad,
              transform: Matrix4.translationValues(0, _showButtons ? 0 : 50, 0),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: math.sin(_controller.value * 3 * math.pi) * 0.2,
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sistema de respaldo automático',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, int delayMs, BuildContext context) {
    return AnimatedOpacity(
      opacity: _showButtons ? 1.0 : 0.0,
      duration: Duration(milliseconds: 800),
      curve: Curves.easeIn,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 800),
        curve: Curves.easeOutQuad,
        transform: Matrix4.translationValues(0, _showButtons ? 0 : 20, 0),
        padding: EdgeInsets.only(
          bottom: ResponsiveHelper.getResponsiveSpacing(context, 14.0),
          top: ResponsiveHelper.getResponsiveSpacing(context, 6.0),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // Nuevo estilo de botón con aspecto Material Design para Android sin animación de brillo azul
  Widget _buildGridMenuButton({
    required GlobalKey key,
    required IconData icon,
    required String label,
    required Color color,
    required int index,
    required String route,
    required int delay,
    bool small = false,
  }) {
    return Builder(
      builder: (context) {
        final iconSize = ResponsiveHelper.getIconSize(
          context,
          small ? 32.0 : 42.0,
        );
        final fontSize = ResponsiveHelper.getResponsiveFontSize(
          context,
          small ? 14.0 : 16.0,
        );
        final padding = ResponsiveHelper.getResponsiveSpacing(
          context,
          small ? 14.0 : 20.0,
        );
        final spacing = ResponsiveHelper.getResponsiveSpacing(
          context,
          small ? 8.0 : 12.0,
        );

        return AnimatedOpacity(
          key: key,
          opacity: _showButtons ? 1.0 : 0.0,
          duration: Duration(milliseconds: 600),
          curve: Curves.easeIn,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 800),
            curve: Curves.easeOutQuad,
            transform: Matrix4.translationValues(0, _showButtons ? 0 : 50, 0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () {
                  // Solo vibración de feedback, sin animación
                  HapticFeedback.mediumImpact();
                  Navigator.pushNamed(context, route);
                },
                borderRadius: BorderRadius.circular(16),
                splashColor: color.withOpacity(0.2),
                highlightColor: color.withOpacity(0.1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: Colors.white,
                        size: iconSize,
                      ),
                      SizedBox(height: spacing),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}