import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/horario.dart';
import '../models/auth_provider.dart';
import '../database/app_database.dart';
import '../widgets/shared_widgets.dart';

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
  bool _isEditing = false;
  String _currentDestino = 'Aysen';
  String _currentCategoria = 'LunesViernes';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentDestino = _tabController.index == 0 ? 'Aysen' : 'Coyhaique';
      });
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

  // Manejar eventos de teclado para scroll con flechas
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

  List<String> _getHorarios(String destino, String categoria) {
    if (destino == 'Aysen') {
      return _horarioManager.horariosAysen[categoria] ?? [];
    } else {
      return _horarioManager.horariosCoyhaique[categoria] ?? [];
    }
  }

  // Ordenar horarios por tiempo
  List<String> _ordenarHorarios(List<String> horarios) {
    horarios.sort((a, b) {
      int minutosA = _convertirAMinutos(a);
      int minutosB = _convertirAMinutos(b);
      return minutosA.compareTo(minutosB);
    });
    return horarios;
  }

  // Convertir horario (HH:MM) a minutos
  int _convertirAMinutos(String horario) {
    List<String> partes = horario.split(':');
    if (partes.length != 2) return 0;

    int horas = int.tryParse(partes[0]) ?? 0;
    int minutos = int.tryParse(partes[1]) ?? 0;

    return horas * 60 + minutos;
  }

  // Eliminar un horario
  Future<void> _eliminarHorario(String horario) async {
    String destino = _currentDestino;
    String categoria = _currentCategoria;

    List<String> horarios = List.from(_getHorarios(destino, categoria));
    horarios.remove(horario);

    await _actualizarHorarios(destino, categoria, horarios);
  }

  // Agregar un nuevo horario desde dropdown
  Future<void> _agregarHorarioDesdeDropdown() async {
    // Generar lista de horarios disponibles (de 05:00 a 23:00 cada 5 minutos)
    List<String> horariosDisponibles = [];
    for (int hora = 5; hora <= 23; hora++) {
      for (int minuto = 0; minuto < 60; minuto += 5) {
        String horario = '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
        horariosDisponibles.add(horario);
      }
    }

    // Filtrar horarios que ya existen
    List<String> horariosActuales = _getHorarios(_currentDestino, _currentCategoria);
    horariosDisponibles = horariosDisponibles.where((h) => !horariosActuales.contains(h)).toList();

    if (horariosDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay más horarios disponibles para agregar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo con dropdown
    String? horarioSeleccionado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Horario'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: horariosDisponibles.length,
            itemBuilder: (context, index) {
              final horario = horariosDisponibles[index];
              return ListTile(
                leading: Icon(Icons.schedule, color: Colors.blue),
                title: Text(
                  horario,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onTap: () => Navigator.pop(context, horario),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR'),
          ),
        ],
      ),
    );

    if (horarioSeleccionado != null) {
      List<String> horarios = List.from(_getHorarios(_currentDestino, _currentCategoria));
      horarios.add(horarioSeleccionado);
      horarios = _ordenarHorarios(horarios);

      await _actualizarHorarios(_currentDestino, _currentCategoria, horarios);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Horario $horarioSeleccionado agregado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Actualizar horarios en memoria, SharedPreferences y DB
  Future<void> _actualizarHorarios(String destino, String categoria, List<String> horarios) async {
    if (destino == 'Aysen') {
      await _horarioManager.actualizarHorariosAysen(categoria, horarios);
    } else {
      await _horarioManager.actualizarHorariosCoyhaique(categoria, horarios);
    }

    // Guardar en la base de datos SQLite
    await _guardarHorariosEnDB(destino, categoria, horarios);

    setState(() {});
  }

  // Guardar horarios en la base de datos SQLite
  Future<void> _guardarHorariosEnDB(String destino, String categoria, List<String> horarios) async {
    try {
      final db = AppDatabase.instance;
      final database = await db.database;

      // Primero, marcar como inactivos los horarios existentes para este destino y categoría
      await database.update(
        'horarios',
        {'activo': 0},
        where: 'activo = 1',
      );

      // Insertar los nuevos horarios
      int orden = 1;
      for (String horario in horarios) {
        await database.insert(
          'horarios',
          {
            'horario': horario,
            'activo': 1,
            'orden': orden,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        orden++;
      }

      debugPrint('Horarios guardados en DB: $destino - $categoria');
    } catch (e) {
      debugPrint('Error al guardar horarios en DB: $e');
    }
  }

  // Restaurar valores por defecto
  Future<void> _restaurarValoresPorDefecto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: 'Restaurar Horarios',
        content: '¿Está seguro que desea restaurar todos los horarios a sus valores originales? Esta acción no se puede deshacer.',
      ),
    );

    if (confirmar == true) {
      await _horarioManager.restaurarValoresPorDefecto();

      // Guardar en DB los valores restaurados
      for (String destino in ['Aysen', 'Coyhaique']) {
        for (String categoria in ['LunesViernes', 'Sabados', 'DomingosFeriados']) {
          List<String> horarios = _getHorarios(destino, categoria);
          await _guardarHorariosEnDB(destino, categoria, horarios);
        }
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Horarios restaurados a valores por defecto'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool puedeEditar = authProvider.isAdmin || authProvider.isSecretaria;

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.schedule, size: 28),
              SizedBox(width: 12),
              Text('Gestión de Horarios'),
            ],
          ),
          centerTitle: true,
          elevation: 2,
          actions: [
            if (puedeEditar)
              IconButton(
                icon: Icon(_isEditing ? Icons.check_circle : Icons.edit),
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
                tooltip: _isEditing ? 'Finalizar edición' : 'Editar horarios',
              ),
            if (!puedeEditar)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Chip(
                  avatar: Icon(Icons.lock, size: 18, color: Colors.white),
                  label: Text(
                    'Solo lectura',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: Colors.grey.shade600,
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 18),
                    SizedBox(width: 8),
                    Text('Aysén'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 18),
                    SizedBox(width: 8),
                    Text('Coyhaique'),
                  ],
                ),
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
                    Text('Cargando horarios...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              )
            : Container(
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
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHorarioTab('Aysen'),
                    _buildHorarioTab('Coyhaique'),
                  ],
                ),
              ),
        floatingActionButton: _isEditing && puedeEditar
            ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    onPressed: _agregarHorarioDesdeDropdown,
                    icon: Icon(Icons.add),
                    label: Text('Agregar Horario'),
                    backgroundColor: Colors.green,
                    heroTag: 'add_horario',
                  ),
                  SizedBox(height: 12),
                  FloatingActionButton(
                    onPressed: _restaurarValoresPorDefecto,
                    child: Icon(Icons.restore),
                    tooltip: 'Restaurar valores predeterminados',
                    backgroundColor: Colors.orange,
                    heroTag: 'restore_horarios',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildHorarioTab(String destino) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thickness: 8,
      radius: Radius.circular(4),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado modernizado
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_bus,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Horarios desde ${destino == 'Aysen' ? 'Aysén' : 'Coyhaique'}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Actualizado y optimizado',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Lunes a Viernes
            _buildHorarioSection(
              'LunesViernes',
              'Lunes a Viernes',
              Icons.calendar_today,
              Colors.amber.shade700,
              destino,
            ),

            SizedBox(height: 24),

            // Sábados
            _buildHorarioSection(
              'Sabados',
              'Sábados',
              Icons.weekend,
              Colors.blue.shade400,
              destino,
            ),

            SizedBox(height: 24),

            // Domingos y Feriados
            _buildHorarioSection(
              'DomingosFeriados',
              'Domingos y Feriados',
              Icons.event,
              Colors.red.shade400,
              destino,
            ),

            SizedBox(height: 32),

            // Nota informativa
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Los horarios están sujetos a cambios por condiciones climáticas o fuerza mayor',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHorarioSection(
    String categoria,
    String titulo,
    IconData icono,
    Color color,
    String destino,
  ) {
    List<String> horarios = _getHorarios(destino, categoria);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado de sección
          Container(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icono,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${horarios.length} horarios',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido de horarios
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: color.withOpacity(0.3), width: 2),
            ),
            child: horarios.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.schedule_outlined, size: 48, color: Colors.grey.shade400),
                          SizedBox(height: 12),
                          Text(
                            'No hay horarios configurados',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: horarios.map((horario) {
                      return _isEditing && _currentDestino == destino && _currentCategoria == categoria
                          ? _buildEditableHorarioChip(horario, color)
                          : _buildHorarioChip(horario, color);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorarioChip(String horario, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 18, color: color),
          SizedBox(width: 8),
          Text(
            horario,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableHorarioChip(String horario, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 18, color: Colors.red.shade700),
          SizedBox(width: 8),
          Text(
            horario,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(width: 8),
          InkWell(
            onTap: () => _eliminarHorario(horario),
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
