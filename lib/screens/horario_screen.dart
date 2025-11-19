import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/horario.dart';
import '../models/auth_provider.dart';

class HorarioScreen extends StatefulWidget {
  @override
  _HorarioScreenState createState() => _HorarioScreenState();
}

class _HorarioScreenState extends State<HorarioScreen> with SingleTickerProviderStateMixin {
  final HorarioManager _horarioManager = HorarioManager();
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = true;
  String _currentDestino = 'Aysen';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentDestino = _tabController.index == 0 ? 'Aysen' : 'Coyhaique';
        });
      }
    });
    _cargarHorarios();
  }

  Future<void> _cargarHorarios() async {
    setState(() {
      _isLoading = true;
    });

    await _horarioManager.cargarHorarios();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Manejar eventos de teclado para scroll
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      const scrollAmount = 50.0;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _scrollController.animateTo(
          _scrollController.offset + scrollAmount,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _scrollController.animateTo(
          _scrollController.offset - scrollAmount,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // Mostrar diálogo de reloj digital para agregar horario
  Future<String?> _mostrarDialogoRelojDigital(
    String destino,
    String categoria,
    bool esSalidaExtra,
  ) async {
    int horaSeleccionada = 12;
    int minutoSeleccionado = 0;

    final isDomingoFeriado = categoria == 'DomingosFeriados';
    final colorPrimario = isDomingoFeriado ? Colors.red : Colors.blue;

    return await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 500,
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorPrimario.shade50,
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          esSalidaExtra ? Icons.add_alarm : Icons.access_time,
                          color: colorPrimario.shade700,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Text(
                          esSalidaExtra ? 'Agregar Salida Extra' : 'Agregar Horario',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorPrimario.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Origen: ${destino == 'Aysen' ? 'Aysén' : 'Coyhaique'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      categoria == 'LunesViernes'
                          ? 'Lunes a Viernes'
                          : (categoria == 'Sabados' ? 'Sábado' : 'Domingo / Feriado'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (esSalidaExtra) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                            SizedBox(width: 6),
                            Text(
                              'Solo válida para hoy',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 32),

                    // Reloj Digital
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorPrimario.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Selector de Hora
                          _buildDigitalTimePicker(
                            value: horaSeleccionada,
                            maxValue: 23,
                            onChanged: (value) {
                              setStateDialog(() {
                                horaSeleccionada = value;
                              });
                            },
                            color: colorPrimario,
                          ),
                          // Separador ":"
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              ':',
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: colorPrimario.shade300,
                                height: 1.0,
                              ),
                            ),
                          ),
                          // Selector de Minuto
                          _buildDigitalTimePicker(
                            value: minutoSeleccionado,
                            maxValue: 59,
                            step: 5,
                            onChanged: (value) {
                              setStateDialog(() {
                                minutoSeleccionado = value;
                              });
                            },
                            color: colorPrimario,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),

                    // Botones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'CANCELAR',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final horario = '${horaSeleccionada.toString().padLeft(2, '0')}:${minutoSeleccionado.toString().padLeft(2, '0')}';
                              Navigator.pop(context, horario);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorPrimario,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'AGREGAR',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Widget para construir el selector digital de tiempo
  Widget _buildDigitalTimePicker({
    required int value,
    required int maxValue,
    int step = 1,
    required ValueChanged<int> onChanged,
    required Color color,
  }) {
    return Column(
      children: [
        // Botón incrementar
        InkWell(
          onTap: () {
            int newValue = value + step;
            if (newValue > maxValue) newValue = 0;
            onChanged(newValue);
          },
          child: Container(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_drop_up,
              color: color.shade300,
              size: 40,
            ),
          ),
        ),
        // Valor actual
        Container(
          width: 100,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.shade700, width: 2),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: color.shade300,
              fontFeatures: [FontFeature.tabularFigures()],
              height: 1.0,
            ),
          ),
        ),
        // Botón decrementar
        InkWell(
          onTap: () {
            int newValue = value - step;
            if (newValue < 0) newValue = maxValue - (maxValue % step);
            onChanged(newValue);
          },
          child: Container(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_drop_down,
              color: color.shade300,
              size: 40,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final puedeEditar = authProvider.isAdmin || authProvider.isSecretaria;

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.schedule, size: 28),
              SizedBox(width: 12),
              Text('Horarios de Salida'),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.indigo.shade700,
          elevation: 2,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.location_on),
                text: 'ORIGEN AYSÉN',
              ),
              Tab(
                icon: Icon(Icons.location_on),
                text: 'ORIGEN COYHAIQUE',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando horarios...'),
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOrigenTab('Aysen', puedeEditar),
                  _buildOrigenTab('Coyhaique', puedeEditar),
                ],
              ),
      ),
    );
  }

  // Construir tab de origen
  Widget _buildOrigenTab(String destino, bool puedeEditar) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Información de contacto
            _buildInfoCard(destino),
            SizedBox(height: 24),

            // Lunes a Viernes
            _buildCategoriaCard(
              destino: destino,
              categoria: 'LunesViernes',
              titulo: 'LUNES A VIERNES',
              icono: Icons.calendar_month,
              colorPrimario: Colors.blue,
              puedeEditar: puedeEditar,
            ),
            SizedBox(height: 16),

            // Sábados
            _buildCategoriaCard(
              destino: destino,
              categoria: 'Sabados',
              titulo: 'SÁBADOS',
              icono: Icons.weekend,
              colorPrimario: Colors.blue,
              puedeEditar: puedeEditar,
            ),
            SizedBox(height: 16),

            // Domingos y Feriados
            _buildCategoriaCard(
              destino: destino,
              categoria: 'DomingosFeriados',
              titulo: 'DOMINGOS Y FERIADOS',
              icono: Icons.event,
              colorPrimario: Colors.red,
              puedeEditar: puedeEditar,
            ),
            SizedBox(height: 16),

            // Botón restaurar valores por defecto (solo admin)
            if (puedeEditar) _buildRestaurarButton(),
          ],
        ),
      ),
    );
  }

  // Tarjeta de información de contacto
  Widget _buildInfoCard(String destino) {
    final contacto = destino == 'Aysen'
        ? _horarioManager.contactoAysen
        : _horarioManager.contactoCoyhaique;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 40, color: Colors.indigo.shade700),
            SizedBox(height: 12),
            Text(
              'Información de Terminal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900,
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_city, size: 16, color: Colors.grey.shade700),
                SizedBox(width: 8),
                Text(
                  contacto['direccion'] ?? '',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                SizedBox(width: 8),
                Text(
                  contacto['telefono'] ?? '',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta de categoría de horarios
  Widget _buildCategoriaCard({
    required String destino,
    required String categoria,
    required String titulo,
    required IconData icono,
    required Color colorPrimario,
    required bool puedeEditar,
  }) {
    // Obtener horarios fijos
    final horariosBase = destino == 'Aysen'
        ? (_horarioManager.horariosAysen[categoria] ?? [])
        : (_horarioManager.horariosCoyhaique[categoria] ?? []);

    // Obtener salidas extras del día
    final salidasExtras = _horarioManager.getSalidasExtrasDelDia(destino, categoria);

    // Combinar y ordenar
    final todosLosHorarios = _horarioManager.obtenerHorariosCompletos(destino, categoria);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorPrimario.shade200, width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorPrimario.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Encabezado
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorPrimario.shade700,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(icono, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (puedeEditar) ...[
                    // Botón agregar horario fijo
                    IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.white),
                      tooltip: 'Agregar Horario Fijo',
                      onPressed: () => _agregarHorarioFijo(destino, categoria, colorPrimario),
                    ),
                    // Botón agregar salida extra
                    IconButton(
                      icon: Icon(Icons.add_alarm, color: Colors.amber.shade300),
                      tooltip: 'Agregar Salida Extra (Solo hoy)',
                      onPressed: () => _agregarSalidaExtra(destino, categoria, colorPrimario),
                    ),
                  ],
                ],
              ),
            ),

            // Lista de horarios
            Padding(
              padding: EdgeInsets.all(16),
              child: todosLosHorarios.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No hay horarios configurados',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: todosLosHorarios.map((horario) {
                        final esSalidaExtra = _horarioManager.esSalidaExtra(
                          horario,
                          destino,
                          categoria,
                        );

                        return _buildHorarioChip(
                          horario: horario,
                          esSalidaExtra: esSalidaExtra,
                          colorPrimario: colorPrimario,
                          puedeEditar: puedeEditar,
                          onEliminar: () {
                            _eliminarHorario(
                              destino,
                              categoria,
                              horario,
                              esSalidaExtra,
                            );
                          },
                        );
                      }).toList(),
                    ),
            ),

            // Indicadores de salidas extras
            if (salidasExtras.isNotEmpty)
              Container(
                margin: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${salidasExtras.length} salida${salidasExtras.length != 1 ? 's' : ''} extra${salidasExtras.length != 1 ? 's' : ''} para hoy',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Chip de horario individual
  Widget _buildHorarioChip({
    required String horario,
    required bool esSalidaExtra,
    required Color colorPrimario,
    required bool puedeEditar,
    required VoidCallback onEliminar,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: esSalidaExtra
            ? LinearGradient(
                colors: [Colors.orange.shade400, Colors.amber.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [colorPrimario.shade600, colorPrimario.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (esSalidaExtra ? Colors.orange : colorPrimario).withOpacity(0.3),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: puedeEditar ? onEliminar : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (esSalidaExtra)
                  Icon(Icons.star, size: 16, color: Colors.white),
                if (esSalidaExtra) SizedBox(width: 6),
                Text(
                  horario,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (puedeEditar) ...[
                  SizedBox(width: 8),
                  Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Botón restaurar valores por defecto
  Widget _buildRestaurarButton() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAdmin) return SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.orange.shade50,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _restaurarValoresPorDefecto,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restore, color: Colors.orange.shade700),
              SizedBox(width: 12),
              Text(
                'RESTAURAR VALORES POR DEFECTO',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Agregar horario fijo
  Future<void> _agregarHorarioFijo(String destino, String categoria, Color colorPrimario) async {
    final horario = await _mostrarDialogoRelojDigital(destino, categoria, false);

    if (horario == null) return;

    // Verificar si ya existe
    final horariosActuales = destino == 'Aysen'
        ? (_horarioManager.horariosAysen[categoria] ?? [])
        : (_horarioManager.horariosCoyhaique[categoria] ?? []);

    if (horariosActuales.contains(horario)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El horario $horario ya existe en esta categoría'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Agregar el nuevo horario
    final nuevosHorarios = List<String>.from(horariosActuales)..add(horario);
    nuevosHorarios.sort((a, b) {
      int minutosA = _convertirAMinutos(a);
      int minutosB = _convertirAMinutos(b);
      return minutosA.compareTo(minutosB);
    });

    if (destino == 'Aysen') {
      await _horarioManager.actualizarHorariosAysen(categoria, nuevosHorarios);
    } else {
      await _horarioManager.actualizarHorariosCoyhaique(categoria, nuevosHorarios);
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Horario $horario agregado exitosamente'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Agregar salida extra
  Future<void> _agregarSalidaExtra(String destino, String categoria, Color colorPrimario) async {
    final horario = await _mostrarDialogoRelojDigital(destino, categoria, true);

    if (horario == null) return;

    // Verificar si ya existe (fijo o extra)
    final todosLosHorarios = _horarioManager.obtenerHorariosCompletos(destino, categoria);

    if (todosLosHorarios.contains(horario)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El horario $horario ya existe en esta categoría'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _horarioManager.agregarSalidaExtra(horario, destino, categoria);

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.star, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text('Salida extra $horario agregada (solo para hoy)'),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  // Eliminar horario
  Future<void> _eliminarHorario(
    String destino,
    String categoria,
    String horario,
    bool esSalidaExtra,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Confirmar Eliminación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Desea eliminar el horario $horario?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            if (esSalidaExtra)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Salida extra (solo hoy)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (esSalidaExtra) {
      // Eliminar salida extra
      await _horarioManager.eliminarSalidaExtra(horario, destino, categoria);
    } else {
      // Eliminar horario fijo
      final horariosActuales = destino == 'Aysen'
          ? (_horarioManager.horariosAysen[categoria] ?? [])
          : (_horarioManager.horariosCoyhaique[categoria] ?? []);

      final nuevosHorarios = List<String>.from(horariosActuales)..remove(horario);

      if (destino == 'Aysen') {
        await _horarioManager.actualizarHorariosAysen(categoria, nuevosHorarios);
      } else {
        await _horarioManager.actualizarHorariosCoyhaique(categoria, nuevosHorarios);
      }
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Horario $horario eliminado'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Restaurar valores por defecto
  Future<void> _restaurarValoresPorDefecto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Confirmar Restauración')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Está seguro de restaurar los horarios a los valores por defecto?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Advertencia:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Se perderán todos los cambios personalizados.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade800,
                    ),
                  ),
                  Text(
                    'Las salidas extras del día se mantendrán.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('RESTAURAR'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _horarioManager.restaurarValoresPorDefecto();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Horarios restaurados a valores por defecto'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Convertir horario a minutos
  int _convertirAMinutos(String horario) {
    List<String> partes = horario.split(':');
    if (partes.length != 2) return 0;
    int horas = int.tryParse(partes[0]) ?? 0;
    int minutos = int.tryParse(partes[1]) ?? 0;
    return horas * 60 + minutos;
  }
}
