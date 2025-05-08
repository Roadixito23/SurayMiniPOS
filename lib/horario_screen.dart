import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'horario.dart';
import 'shared_widgets.dart';

class HorarioScreen extends StatefulWidget {
  @override
  _HorarioScreenState createState() => _HorarioScreenState();
}

class _HorarioScreenState extends State<HorarioScreen> with SingleTickerProviderStateMixin {
  final HorarioManager _horarioManager = HorarioManager();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isEditing = false;
  String _currentDestino = 'Aysen';
  String _currentCategoria = 'LunesViernes';

  // Controladores para agregar nuevos horarios
  final TextEditingController _newHorarioController = TextEditingController();

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
    _newHorarioController.dispose();
    super.dispose();
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
      // Convertir los horarios a minutos para comparar
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

    if (destino == 'Aysen') {
      await _horarioManager.actualizarHorariosAysen(categoria, horarios);
    } else {
      await _horarioManager.actualizarHorariosCoyhaique(categoria, horarios);
    }

    setState(() {});
  }

  // Agregar un nuevo horario
  Future<void> _agregarHorario() async {
    String nuevoHorario = _newHorarioController.text.trim();
    if (nuevoHorario.isEmpty) return;

    // Validar formato HH:MM
    RegExp regex = RegExp(r'^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$');
    if (!regex.hasMatch(nuevoHorario)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Formato inválido. Use HH:MM (Ejemplo: 14:30)'))
      );
      return;
    }

    String destino = _currentDestino;
    String categoria = _currentCategoria;

    List<String> horarios = List.from(_getHorarios(destino, categoria));

    // Verificar si ya existe
    if (horarios.contains(nuevoHorario)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Este horario ya existe'))
      );
      return;
    }

    horarios.add(nuevoHorario);
    horarios = _ordenarHorarios(horarios);

    if (destino == 'Aysen') {
      await _horarioManager.actualizarHorariosAysen(categoria, horarios);
    } else {
      await _horarioManager.actualizarHorariosCoyhaique(categoria, horarios);
    }

    _newHorarioController.clear();
    setState(() {});
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
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Horarios restaurados a valores por defecto'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Horarios de Buses'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
            tooltip: _isEditing ? 'Guardar cambios' : 'Editar horarios',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Aysén'),
            Tab(text: 'Coyhaique'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildHorarioTab('Aysen'),
          _buildHorarioTab('Coyhaique'),
        ],
      ),
      bottomNavigationBar: _isEditing
          ? _buildBottomEditor()
          : null,
      floatingActionButton: _isEditing
          ? FloatingActionButton(
        onPressed: _restaurarValoresPorDefecto,
        child: Icon(Icons.restore),
        tooltip: 'Restaurar valores predeterminados',
      )
          : null,
    );
  }

  Widget _buildBottomEditor() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Colors.blue.shade50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: TextField(
                    controller: _newHorarioController,
                    decoration: InputDecoration(
                      hintText: 'Nuevo horario (HH:MM)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: InputBorder.none,
                    ),
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: _agregarHorario,
                child: Text('Agregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCategoriaButton('LunesViernes', 'Lunes a Viernes'),
              SizedBox(width: 8),
              _buildCategoriaButton('Sabados', 'Sábados'),
              SizedBox(width: 8),
              _buildCategoriaButton('DomingosFeriados', 'Domingos/Feriados'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaButton(String categoria, String label) {
    bool isSelected = _currentCategoria == categoria;
    return InkWell(
      onTap: () {
        setState(() {
          _currentCategoria = categoria;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHorarioTab(String destino) {
    Map<String, String> contacto = destino == 'Aysen'
        ? _horarioManager.contactoAysen
        : _horarioManager.contactoCoyhaique;

    Map<String, String> correspondencia = destino == 'Aysen'
        ? _horarioManager.correspondenciaAysen
        : _horarioManager.correspondenciaCoyhaique;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y dirección
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Salidas desde ${destino == 'Aysen' ? 'Aysén' : 'Coyhaique'}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.yellow,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      contacto['direccion'] ?? '',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.phone, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      contacto['telefono'] ?? '',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Lunes a Viernes
          _buildHorarioSection(
            'LunesViernes',
            'Lunes a Viernes',
            Colors.yellow.shade700,
            destino,
          ),

          SizedBox(height: 16),

          // Sábados
          _buildHorarioSection(
            'Sabados',
            'Sábados',
            Colors.blue.shade300,
            destino,
          ),

          SizedBox(height: 16),

          // Domingos y Feriados
          _buildHorarioSection(
            'DomingosFeriados',
            'Domingos o Feriados',
            Colors.red.shade400,
            destino,
          ),

          SizedBox(height: 20),

          // Correspondencia
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CORRESPONDENCIA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue.shade800, size: 14),
                    SizedBox(width: 4),
                    Text(
                      correspondencia['direccion'] ?? '',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.phone, color: Colors.blue.shade800, size: 14),
                    SizedBox(width: 4),
                    Text(
                      correspondencia['telefono'] ?? '',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  correspondencia['horario'] ?? '',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Nota al pie
          Center(
            child: Text(
              'Horarios sujetos a cambios por fuerza mayor',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHorarioSection(String categoria, String titulo, Color color, String destino) {
    List<String> horarios = _getHorarios(destino, categoria);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color == Colors.yellow.shade700 ? Colors.black : Colors.white,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: color),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: horarios.map((horario) {
              return _isEditing && _currentDestino == destino && _currentCategoria == categoria
                  ? _buildEditableHorarioChip(horario)
                  : _buildHorarioChip(horario, color);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHorarioChip(String horario, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        horario,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEditableHorarioChip(String horario) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            horario,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          SizedBox(width: 4),
          InkWell(
            onTap: () => _eliminarHorario(horario),
            child: Icon(
              Icons.close,
              size: 16,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}