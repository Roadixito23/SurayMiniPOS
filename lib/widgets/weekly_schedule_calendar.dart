import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/horario.dart';

class WeeklyScheduleCalendar extends StatefulWidget {
  final HorarioManager horarioManager;
  final String destino;
  final String tipoDia;
  final Function(String fecha, String horario)? onHorarioSelected;

  const WeeklyScheduleCalendar({
    required this.horarioManager,
    required this.destino,
    required this.tipoDia,
    this.onHorarioSelected,
  });

  @override
  _WeeklyScheduleCalendarState createState() => _WeeklyScheduleCalendarState();
}

class _WeeklyScheduleCalendarState extends State<WeeklyScheduleCalendar> {
  int _weekOffset = 0; // 0 = semana actual, 1 = siguiente semana, etc.
  DateTime? _selectedDate;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<DateTime> _getWeekDates() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Lunes
    final weekStart = startOfWeek.add(Duration(days: 7 * _weekOffset));

    return List.generate(7, (index) => weekStart.add(Duration(days: index)));
  }

  String _getCategoriaForDate(DateTime date) {
    if (widget.tipoDia == 'DOMINGO / FERIADO') {
      return 'DomingosFeriados';
    } else if (date.weekday == 6) {
      return 'Sabados';
    } else {
      return 'LunesViernes';
    }
  }

  Color _getColorForDayType(String categoria) {
    switch (categoria) {
      case 'DomingosFeriados':
        return Colors.red;
      case 'Sabados':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Future<void> _showAddScheduleDialog(DateTime date) async {
    final categoria = _getCategoriaForDate(date);
    final fecha = DateFormat('yyyy-MM-dd').format(date);

    int horaSeleccionada = 12;
    int minutoSeleccionado = 0;

    final isDomingoFeriado = categoria == 'DomingosFeriados';
    final colorPrimario = _getColorForDayType(categoria);

    return await showDialog<void>(
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
                          Icons.add_alarm,
                          color: colorPrimario.shade700,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Agregar Horario',
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
                      DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(date),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Destino: ${widget.destino}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                            onPressed: () async {
                              final horario = '${horaSeleccionada.toString().padLeft(2, '0')}:${minutoSeleccionado.toString().padLeft(2, '0')}';
                              await widget.horarioManager.agregarHorarioProgramado(
                                fecha,
                                widget.destino,
                                categoria,
                                horario,
                              );
                              Navigator.pop(context);
                              setState(() {}); // Actualizar vista
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Horario $horario agregado para ${DateFormat('dd/MM/yyyy').format(date)}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
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

  Widget _buildDigitalTimePicker({
    required int value,
    required int maxValue,
    int step = 1,
    required ValueChanged<int> onChanged,
    required MaterialColor color,
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

  Future<void> _showScheduleDetailsDialog(DateTime date) async {
    final categoria = _getCategoriaForDate(date);
    final fecha = DateFormat('yyyy-MM-dd').format(date);
    final colorPrimario = _getColorForDayType(categoria);

    // Obtener horarios para esta fecha
    final horariosProgramados = widget.horarioManager.getHorariosProgramados(fecha, widget.destino, categoria);
    final horariosBase = widget.horarioManager.obtenerHorariosCompletos(widget.destino, categoria, fecha: fecha);
    final tieneHorariosProgramados = widget.horarioManager.tieneHorariosProgramados(fecha, widget.destino, categoria);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 600,
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Row(
                  children: [
                    Icon(Icons.schedule, color: colorPrimario.shade700, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Horarios Programados',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorPrimario.shade700,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(date),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Indicador de horarios
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tieneHorariosProgramados ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tieneHorariosProgramados ? Colors.green.shade300 : Colors.blue.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tieneHorariosProgramados ? Icons.event_available : Icons.event,
                        color: tieneHorariosProgramados ? Colors.green.shade700 : Colors.blue.shade700,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tieneHorariosProgramados
                              ? 'Horarios personalizados para esta fecha (${horariosProgramados.length} horarios)'
                              : 'Usando horarios predeterminados (${horariosBase.length} horarios)',
                          style: TextStyle(
                            fontSize: 13,
                            color: tieneHorariosProgramados ? Colors.green.shade800 : Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Lista de horarios
                Container(
                  constraints: BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: horariosBase.length,
                    itemBuilder: (context, index) {
                      final horario = horariosBase[index];
                      final esPersonalizado = tieneHorariosProgramados;

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: esPersonalizado ? Colors.green.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: esPersonalizado ? Colors.green.shade200 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: colorPrimario.shade600,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                horario,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Spacer(),
                              if (esPersonalizado)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red.shade600),
                                  onPressed: () async {
                                    await widget.horarioManager.eliminarHorarioProgramado(
                                      fecha,
                                      widget.destino,
                                      categoria,
                                      horario,
                                    );
                                    Navigator.pop(context);
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Horario $horario eliminado'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),

                // Botones de acción
                Row(
                  children: [
                    if (!tieneHorariosProgramados)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Copiar horarios base como personalizados
                            await widget.horarioManager.setHorariosProgramados(
                              fecha,
                              widget.destino,
                              categoria,
                              List.from(horariosBase),
                            );
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Horarios copiados. Ahora puedes personalizarlos.'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                          icon: Icon(Icons.copy_all, size: 18),
                          label: Text('PERSONALIZAR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (tieneHorariosProgramados) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await widget.horarioManager.setHorariosProgramados(
                              fecha,
                              widget.destino,
                              categoria,
                              [],
                            );
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Horarios personalizados eliminados'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          icon: Icon(Icons.restore, size: 18),
                          label: Text('RESTAURAR'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade300),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddScheduleDialog(date);
                        },
                        icon: Icon(Icons.add, size: 18),
                        label: Text('AGREGAR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrimario,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CERRAR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    setState(() {}); // Actualizar vista después de cerrar
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _getWeekDates();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // Encabezado
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.blue.shade700, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendario de Horarios',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        'Gestiona horarios hasta 3 semanas adelante',
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

            // Selector de semana
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed: _weekOffset > 0
                      ? () => setState(() => _weekOffset--)
                      : null,
                ),
                SizedBox(width: 16),
                Text(
                  _weekOffset == 0
                      ? 'Semana Actual'
                      : _weekOffset == 1
                          ? 'Próxima Semana'
                          : 'Semana ${_weekOffset + 1}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed: _weekOffset < 2
                      ? () => setState(() => _weekOffset++)
                      : null,
                ),
              ],
            ),
            SizedBox(height: 24),

            // Calendario Semanal
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.7,
                ),
                itemCount: weekDates.length,
                itemBuilder: (context, index) {
                  final date = weekDates[index];
                  final isToday = DateTime(date.year, date.month, date.day) == today;
                  final isPast = date.isBefore(today);
                  final categoria = _getCategoriaForDate(date);
                  final fecha = DateFormat('yyyy-MM-dd').format(date);
                  final tieneHorariosProgramados = widget.horarioManager.tieneHorariosProgramados(fecha, widget.destino, categoria);
                  final horarios = widget.horarioManager.obtenerHorariosCompletos(widget.destino, categoria, fecha: fecha);
                  final colorDia = _getColorForDayType(categoria);

                  return InkWell(
                    onTap: isPast ? null : () => _showScheduleDetailsDialog(date),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPast
                            ? Colors.grey.shade100
                            : isToday
                                ? colorDia.shade100
                                : tieneHorariosProgramados
                                    ? Colors.green.shade50
                                    : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isToday
                              ? colorDia.shade600
                              : tieneHorariosProgramados
                                  ? Colors.green.shade400
                                  : Colors.grey.shade300,
                          width: isToday ? 3 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Día de la semana
                          Text(
                            DateFormat('EEE', 'es_ES').format(date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPast ? Colors.grey : colorDia.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          // Número del día
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isToday ? colorDia.shade600 : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isToday ? Colors.white : (isPast ? Colors.grey : Colors.black87),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Indicador de horarios
                          if (!isPast) ...[
                            Icon(
                              tieneHorariosProgramados ? Icons.event_available : Icons.event,
                              size: 16,
                              color: tieneHorariosProgramados ? Colors.green.shade700 : Colors.blue.shade600,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${horarios.length}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: tieneHorariosProgramados ? Colors.green.shade700 : Colors.blue.shade600,
                              ),
                            ),
                            Text(
                              tieneHorariosProgramados ? 'custom' : 'std',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 16),

            // Leyenda
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(Colors.blue, 'Lun-Vie'),
                _buildLegendItem(Colors.orange, 'Sábado'),
                _buildLegendItem(Colors.red, 'Dom/Fer'),
                _buildLegendItem(Colors.green, 'Personalizado'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(MaterialColor color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.shade100,
            border: Border.all(color: color.shade400, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
