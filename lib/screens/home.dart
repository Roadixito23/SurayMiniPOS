import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/auth_provider.dart';
import '../database/app_database.dart';
import 'dart:math' as math;

// Imports añadidos para la simulación de datos
import 'dart:math';
import 'package:intl/intl.dart';
import '../database/caja_database.dart';
import '../models/comprobante.dart';
import '../models/tarifa.dart';

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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _settingsButtonController;
  late AnimationController _floatingAnimationController;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String _secretCode = '';
  bool _showSettingsButton = false;
  bool _showDebugButtons = false;
  bool _isLoading = false; // Variable de estado para la carga de la DB

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _settingsButtonController = AnimationController(
      duration: Duration(milliseconds: 600),
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
    _settingsButtonController.dispose();
    _floatingAnimationController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.character?.toLowerCase();
      if (key != null && key.length == 1) {
        setState(() {
          _secretCode += key;
          // Mantener solo los últimos 13 caracteres (longitud de "administrador")
          if (_secretCode.length > 13) {
            _secretCode = _secretCode.substring(_secretCode.length - 13);
          }

          // Verificar si se escribió "administrador"
          if (_secretCode.contains('administrador')) {
            if (!_showSettingsButton) {
              _showSettingsButton = true;
              _settingsButtonController.forward();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white),
                      SizedBox(width: 12),
                      Text('¡Modo administrador activado!'),
                    ],
                  ),
                  backgroundColor: Colors.green.shade600,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            _secretCode = ''; // Reiniciar el código secreto
          }

          // Verificar si se escribió "debug" para mostrar botones de base de datos
          if (_secretCode.contains('debug')) {
            setState(() {
              _showDebugButtons = !_showDebugButtons;
            });
            _secretCode = '';
          }
        });
      }
    }
  }

  /// REEMPLAZADO: Método para poblar la base de datos con datos de simulación
  Future<void> _poblarBaseDatos() async {
    try {
      // Mostrar diálogo de confirmación
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 12),
              Text('Poblar Base de Datos'),
            ],
          ),
          content: Text('¿Está seguro de agregar datos de simulación? Esto generará ~100 ventas y gastos ficticios para el día de hoy.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('CONFIRMAR'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      setState(() => _isLoading = true);

      final cajaDb = CajaDatabase();
      final appDb = AppDatabase.instance;
      final comprobanteManager = ComprobanteManager();
      await comprobanteManager.initialize(); // Asegurar que esté inicializado
      final random = Random();

      final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String tipoDiaHoy = DateTime.now().weekday >= 6 ? 'DOMINGO / FERIADO' : 'LUNES A SÁBADO';

      // Obtener tarifas disponibles para hoy
      final tarifasMap = await appDb.getTarifasByTipoDia(tipoDiaHoy);
      final tarifas = tarifasMap.map((t) => Tarifa.fromMap(t)).toList();

      if (tarifas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No hay tarifas configuradas para poblar datos.'), backgroundColor: Colors.orange),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final List<String> horariosSalida = ['08:30', '09:45', '11:00', '12:00', '14:10', '15:40', '17:00', '19:50'];
      final List<String> destinos = ['Aysen', 'Coyhaique'];
      final List<String> nombres = ['Ana', 'Bruno', 'Carla', 'David', 'Elena', 'Felipe', 'Gala', 'Hugo', 'Ines', 'Juan'];

      // 1. Poblar Ventas de Bus (Simulamos 80 ventas)
      int ventasBusGeneradas = 0;
      for (int i = 0; i < 80; i++) {
        // Seleccionar una tarifa al azar (omitir intermedios para este bucle simple)
        final tarifa = tarifas[random.nextInt(tarifas.length)];
        if (tarifa.categoria.toUpperCase().contains('INTERMEDIO')) continue;

        final horario = horariosSalida[random.nextInt(horariosSalida.length)];
        final destino = destinos[random.nextInt(destinos.length)];
        final asiento = random.nextInt(45) + 1; // Asiento aleatorio 1-45
        final esEfectivo = random.nextBool();
        final valor = tarifa.valor;

        // Generar comprobante real
        final String numeroComprobante = await comprobanteManager.getNextBusComprobante(tarifa.categoria);

        // Registrar en CajaDatabase
        await cajaDb.registrarVentaBus(
          destino: destino,
          horario: horario,
          asiento: asiento.toString().padLeft(2, '0'),
          valor: valor,
          comprobante: numeroComprobante,
          tipoBoleto: tarifa.categoria,
          metodoPago: esEfectivo ? 'Efectivo' : 'Tarjeta',
          montoEfectivo: esEfectivo ? valor : 0,
          montoTarjeta: esEfectivo ? 0 : valor,
        );

        // Registrar en AppDatabase (mapa de asientos)
        final salidaId = await appDb.crearObtenerSalida(
          fecha: fechaHoy,
          horario: horario,
          destino: destino,
          tipoDia: tipoDiaHoy,
        );

        try {
          // Intentar reservar el asiento
          await appDb.reservarAsiento(
            salidaId: salidaId,
            numeroAsiento: asiento,
            comprobante: numeroComprobante,
          );
        } catch (e) {
          // Ignorar error de asiento duplicado (UNIQUE constraint)
          // Esto es normal y esperado en una simulación aleatoria
        }
        ventasBusGeneradas++;
      }

      // 2. Poblar Ventas de Carga (Simulamos 15 ventas)
      for (int i = 0; i < 15; i++) {
        final String numeroComprobante = await comprobanteManager.getNextCargoComprobante();
        final valor = (random.nextInt(20) + 5) * 1000.0; // 5000 a 25000
        await cajaDb.registrarVentaCargo(
          remitente: '${nombres[random.nextInt(nombres.length)]} ${nombres[random.nextInt(nombres.length)]}',
          destinatario: '${nombres[random.nextInt(nombres.length)]} ${nombres[random.nextInt(nombres.length)]}',
          destino: destinos[random.nextInt(destinos.length)],
          articulo: 'Caja N°${random.nextInt(100)}',
          valor: valor,
          comprobante: numeroComprobante,
          metodoPago: 'Efectivo',
          montoEfectivo: valor,
          montoTarjeta: 0,
        );
      }

      // 3. Poblar Gastos (Simulamos 2 gastos)
      await cajaDb.registrarGasto(
        tipoGasto: 'Combustible',
        monto: 75000.0,
        numeroMaquina: 'AB-123',
        chofer: 'Juan Perez',
      );
      await cajaDb.registrarGasto(
        tipoGasto: 'Otros',
        monto: 15000.0,
        descripcion: 'Insumos oficina',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Base de datos poblada con $ventasBusGeneradas ventas de bus, 15 de carga y 2 gastos.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al poblar base de datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _limpiarBaseDatos() async {
    try {
      // Mostrar diálogo de confirmación
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red),
              SizedBox(width: 12),
              Text('Limpiar Base de Datos'),
            ],
          ),
          content: Text(
            '¿Está COMPLETAMENTE SEGURO de eliminar TODOS los datos?\n\nEsta acción NO se puede deshacer.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('ELIMINAR TODO'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      final db = AppDatabase.instance;
      await db.limpiarTodasLasTablas();

      // Adicionalmente, limpiar los archivos JSON de caja
      final cajaDb = CajaDatabase();
      await cajaDb.limpiarDatos();

      // Reiniciar comprobantes
      await ComprobanteManager().resetCounter();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Base de datos limpiada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al limpiar base de datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

            // Botón de ajustes animado (aparece al escribir "administrador")
            if (_showSettingsButton)
              Positioned(
                top: 80,
                right: 20,
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _settingsButtonController,
                    curve: Curves.elasticOut,
                  ),
                  child: FloatingActionButton.extended(
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    backgroundColor: Colors.orange.shade600,
                    icon: Icon(Icons.settings, color: Colors.white),
                    label: Text(
                      'Configuración',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    heroTag: 'settings_button',
                  ),
                ),
              ),

            // Botones de debug (aparecen al escribir "debug")
            if (_showDebugButtons)
              Positioned(
                bottom: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: _isLoading ? null : _poblarBaseDatos, // MODIFICADO
                      backgroundColor: Colors.green.shade600,
                      icon: Icon(Icons.add_circle, color: Colors.white),
                      label: _isLoading // MODIFICADO
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                        'Poblar DB',
                        style: TextStyle(color: Colors.white),
                      ),
                      heroTag: 'populate_db',
                    ),
                    SizedBox(height: 12),
                    FloatingActionButton.extended(
                      onPressed: _isLoading ? null : _limpiarBaseDatos, // MODIFICADO
                      backgroundColor: Colors.red.shade600,
                      icon: Icon(Icons.delete_forever, color: Colors.white),
                      label: Text(
                        'Limpiar DB',
                        style: TextStyle(color: Colors.white),
                      ),
                      heroTag: 'clear_db',
                    ),
                  ],
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
        duration: Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        child: Card(
          elevation: _isHovered ? 12 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: _isHovered ? LinearGradient(
                  colors: [
                    widget.color.withOpacity(0.05),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ) : null,
              ),
              padding: EdgeInsets.all(20),
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
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isHovered ? widget.color.withOpacity(0.1) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.shortcut,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isHovered ? widget.color : Colors.grey.shade700,
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