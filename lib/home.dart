import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'dart:math' as math;

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Suray MiniPOS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {},
            tooltip: 'Perfil',
          ),
        ],
      ),
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
  final List<GlobalKey> _buttonKeys = List.generate(5, (_) => GlobalKey());
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

  void _animateButtonTap(int index) {
    final renderBox = _buttonKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      final overlay = Overlay.of(context);
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (context) => Positioned(
          left: position.dx,
          top: position.dy,
          width: size.width,
          height: size.height,
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 1.0, end: 1.2),
            duration: Duration(milliseconds: 200),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              );
            },
            onEnd: () {
              entry.remove();
            },
          ),
        ),
      );

      overlay.insert(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Center(
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: Duration(milliseconds: 1500),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
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
                              height: 120,
                              width: 120,
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
                          height: 80,
                          width: 80,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24),
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
                    'Bienvenido a Suray MiniPOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 30),
          _buildSectionTitle('Menú Principal', 300),
          ..._buildAnimatedButtons(),
          SizedBox(height: 15),
          Divider(color: Colors.blue.shade100, thickness: 1),
          _buildSectionTitle('Administración', 600),
          _buildAnimatedMenuButton(
            key: _buttonKeys[3],
            icon: Icons.calculate,
            label: 'Cierre de Caja',
            color: Colors.green.shade600,
            index: 3,
            route: '/cierre_caja',
            delay: 900,
          ),
          SizedBox(height: 15),
          _buildAnimatedMenuButton(
            key: _buttonKeys[4],
            icon: Icons.storage,
            label: 'Gestión de Datos',
            color: Colors.indigo,
            index: 4,
            route: '/data_management',
            delay: 1000,
          ),
          SizedBox(height: 30),
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
          SizedBox(height: 30),
        ],
      ),
    );
  }

  List<Widget> _buildAnimatedButtons() {
    return [
      _buildAnimatedMenuButton(
        key: _buttonKeys[0],
        icon: Icons.airline_seat_recline_normal,
        label: 'Venta de Pasajes',
        color: Colors.blue,
        index: 0,
        route: '/venta_bus',
        delay: 700,
      ),
      SizedBox(height: 15),
      _buildAnimatedMenuButton(
        key: _buttonKeys[1],
        icon: Icons.inventory,
        label: 'Venta de Carga',
        color: Colors.purple,
        index: 1,
        route: '/venta_cargo',
        delay: 800,
      ),
      SizedBox(height: 15),
      _buildAnimatedMenuButton(
        key: _buttonKeys[2],
        icon: Icons.history,
        label: 'Historial de Carga',
        color: Colors.orange,
        index: 2,
        route: '/cargo_history',
        delay: 850,
      ),
    ];
  }

  Widget _buildAnimatedMenuButton({
    required GlobalKey key,
    required IconData icon,
    required String label,
    required Color color,
    required int index,
    required String route,
    required int delay,
  }) {
    return AnimatedOpacity(
      key: key,
      opacity: _showButtons ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeIn,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 800),
        curve: Curves.easeOutQuad,
        transform: Matrix4.translationValues(_showButtons ? 0 : -100, 0, 0),
        margin: EdgeInsets.only(left: _showButtons ? 0 : 50),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _animateButtonTap(index);
                HapticFeedback.mediumImpact();
                Future.delayed(Duration(milliseconds: 300), () {
                  Navigator.pushNamed(context, route);
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 28),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, int delayMs) {
    return AnimatedOpacity(
      opacity: _showButtons ? 1.0 : 0.0,
      duration: Duration(milliseconds: 800),
      curve: Curves.easeIn,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 800),
        curve: Curves.easeOutQuad,
        transform: Matrix4.translationValues(0, _showButtons ? 0 : 20, 0),
        padding: const EdgeInsets.only(bottom: 14.0, top: 6.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
