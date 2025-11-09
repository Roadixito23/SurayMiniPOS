import 'package:flutter/material.dart';
import 'numeric_input_field.dart';
import '../models/horario.dart';

class HorarioInputField extends StatefulWidget {
  final String? value;
  final Function(String) onChanged;
  final String? Function(String)? validator;
  final VoidCallback? onEnterPressed;
  final FocusNode? focusNode;
  final String destino; // Destino seleccionado (Aysen, Intermedio o Coyhaique)
  final String origenIntermedio; // Nuevo parámetro para el origen en caso intermedio
  final String? fechaSeleccionada; // Fecha seleccionada para filtrar horarios pasados

  const HorarioInputField({
    Key? key,
    this.value,
    required this.onChanged,
    this.validator,
    this.onEnterPressed,
    this.focusNode,
    required this.destino,
    this.origenIntermedio = 'Aysen', // Valor predeterminado
    this.fechaSeleccionada,
  }) : super(key: key);

  @override
  _HorarioInputFieldState createState() => _HorarioInputFieldState();
}

class _HorarioInputFieldState extends State<HorarioInputField> {
  final HorarioManager _horarioManager = HorarioManager();
  List<String> _todasLasSugerencias = []; // Guarda todas las sugerencias sin filtrar
  List<String> _sugerenciasFiltradas = []; // Sugerencias filtradas para mostrar
  String _currentInput = '';

  @override
  void initState() {
    super.initState();
    _currentInput = widget.value ?? '';
    _cargarSugerencias();
  }

  @override
  void didUpdateWidget(HorarioInputField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.destino != oldWidget.destino ||
        widget.origenIntermedio != oldWidget.origenIntermedio) {
      _cargarSugerencias();
    }

    if (widget.value != oldWidget.value) {
      setState(() {
        _currentInput = widget.value ?? '';
        _filtrarSugerencias();
      });
    }
  }

  // Obtener la fuente de horarios según el destino y origen
  String _obtenerFuenteHorarios() {
    // Si es destino intermedio, usar los horarios del origen seleccionado
    if (widget.destino == 'Intermedio') {
      return widget.origenIntermedio;
    }
    // En caso contrario, mostrar los horarios del destino opuesto como antes
    else {
      return widget.destino == 'Aysen' ? 'Coyhaique' : 'Aysen';
    }
  }

  // Carga las sugerencias basadas en el día actual y la fuente de horarios
  void _cargarSugerencias() {
    // Obtener el día de la semana actual
    final ahora = DateTime.now();
    final diaSemana = ahora.weekday; // 1-7 donde 1 es Lunes, 7 es Domingo

    String categoria;
    if (diaSemana >= 1 && diaSemana <= 5) {
      categoria = 'LunesViernes';
    } else if (diaSemana == 6) {
      categoria = 'Sabados';
    } else {
      categoria = 'DomingosFeriados';
    }

    // Obtener la fuente de los horarios (origen o destino opuesto)
    String fuenteHorarios = _obtenerFuenteHorarios();

    // Obtener los horarios según la fuente
    Map<String, List<String>> horarios = fuenteHorarios == 'Aysen'
        ? _horarioManager.horariosAysen
        : _horarioManager.horariosCoyhaique;

    setState(() {
      _todasLasSugerencias = List<String>.from(horarios[categoria] ?? []);
      _filtrarSugerencias();
    });
  }

  // Filtra las sugerencias basadas en la entrada actual
  void _filtrarSugerencias() {
    final ahora = DateTime.now();
    final esHoy = widget.fechaSeleccionada != null &&
                  widget.fechaSeleccionada == DateTime(ahora.year, ahora.month, ahora.day)
                      .toString().split(' ')[0];
    final horaActual = TimeOfDay.now();

    setState(() {
      List<String> sugerenciasDisponibles = _todasLasSugerencias;

      // Si es hoy, filtrar horarios que ya pasaron
      if (esHoy) {
        sugerenciasDisponibles = _todasLasSugerencias.where((horario) {
          final partes = horario.split(':');
          if (partes.length == 2) {
            final hora = int.tryParse(partes[0]);
            final minuto = int.tryParse(partes[1]);
            if (hora != null && minuto != null) {
              // Comparar si el horario es mayor a la hora actual
              if (hora > horaActual.hour) return true;
              if (hora == horaActual.hour && minuto > horaActual.minute) return true;
              return false;
            }
          }
          return true;
        }).toList();
      }

      if (_currentInput.isEmpty) {
        // Mostrar todas las sugerencias disponibles si no hay entrada
        _sugerenciasFiltradas = List<String>.from(sugerenciasDisponibles);
      } else {
        // Filtrar por lo que haya escrito el usuario
        _sugerenciasFiltradas = sugerenciasDisponibles
            .where((horario) => horario.startsWith(_currentInput))
            .toList();
      }
    });
  }

  void _handleInputChanged(String value) {
    setState(() {
      _currentInput = value;
      _filtrarSugerencias();
    });

    widget.onChanged(value);
  }

  void _seleccionarSugerencia(String horario) {
    _handleInputChanged(horario);
  }

  // Mostrar un texto descriptivo sobre la fuente de los horarios
  String _getDescripcionFuente() {
    String fuenteHorarios = _obtenerFuenteHorarios();
    final ahora = DateTime.now();
    final esHoy = widget.fechaSeleccionada != null &&
                  widget.fechaSeleccionada == DateTime(ahora.year, ahora.month, ahora.day)
                      .toString().split(' ')[0];

    String descripcion;
    if (widget.destino == 'Intermedio') {
      descripcion = "(horarios de salida desde $fuenteHorarios)";
    } else {
      descripcion = "(sugerencias de $fuenteHorarios)";
    }

    if (esHoy) {
      descripcion += " - HOY";
    }

    return descripcion;
  }

  // Construir el widget de sugerencias que irá encima del teclado
  Widget _buildSuggestionsWidget() {
    // Si no hay sugerencias que mostrar, devolver un contenedor con mensaje
    if (_sugerenciasFiltradas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
        ),
        child: Center(
          child: Text(
            _currentInput.isEmpty
                ? 'No hay horarios disponibles para hoy'
                : 'No hay coincidencias para "${_currentInput}"',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // Si hay sugerencias, mostrar la lista horizontal
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: _sugerenciasFiltradas.length,
        itemBuilder: (context, index) {
          final horario = _sugerenciasFiltradas[index];
          final bool isSelected = _currentInput == horario;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _seleccionarSugerencia(horario),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade100 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      horario,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.blue.shade700 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Horario',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(width: 8),
            Text(
              _getDescripcionFuente(),
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),

        // Campo de entrada numérica con sugerencias encima del teclado
        NumericInputField(
          value: _currentInput,
          hintText: 'HH:MM',
          validator: widget.validator,
          focusNode: widget.focusNode,
          onChanged: _handleInputChanged,
          onEnterPressed: widget.onEnterPressed,
          suggestionsWidget: _buildSuggestionsWidget(), // Pasamos las sugerencias
        ),
      ],
    );
  }
}