import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/horario.dart';

class HorarioSelectorDialog extends StatefulWidget {
  final List<String> horarios;
  final HorarioManager horarioManager;
  final String destino;
  final String categoria;
  final bool isDomingoFeriado;
  final Future<String?> Function() onAgregarNuevo;

  const HorarioSelectorDialog({
    required this.horarios,
    required this.horarioManager,
    required this.destino,
    required this.categoria,
    required this.isDomingoFeriado,
    required this.onAgregarNuevo,
  });

  @override
  _HorarioSelectorDialogState createState() => _HorarioSelectorDialogState();
}

class _HorarioSelectorDialogState extends State<HorarioSelectorDialog> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _moveSelection(int delta) {
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, widget.horarios.length - 1);
      // Auto-scroll
      if (_scrollController.hasClients) {
        final itemHeight = 60.0;
        final targetOffset = _selectedIndex * itemHeight;
        _scrollController.animateTo(
          targetOffset,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _selectCurrent() {
    if (_selectedIndex >= 0 && _selectedIndex < widget.horarios.length) {
      Navigator.pop(context, widget.horarios[_selectedIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moveSelection(1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moveSelection(-1);
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            _selectCurrent();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          }
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    color: widget.isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'SELECCIONAR HORARIO',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Use ↑↓ para navegar, Enter para seleccionar',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 24),

              // Lista de horarios
              Container(
                constraints: BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  itemCount: widget.horarios.length,
                  itemBuilder: (context, index) {
                    final horario = widget.horarios[index];
                    final isSelected = index == _selectedIndex;
                    final esSalidaExtra = widget.horarioManager.esSalidaExtra(
                      horario,
                      widget.destino,
                      widget.categoria,
                    );

                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: isSelected
                            ? (widget.isDomingoFeriado ? Colors.red.shade100 : Colors.blue.shade100)
                            : (esSalidaExtra ? Colors.amber.shade50 : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        elevation: isSelected ? 4 : 1,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, horario),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? (widget.isDomingoFeriado ? Colors.red.shade400 : Colors.blue.shade400)
                                    : Colors.grey.shade200,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (esSalidaExtra) ...[
                                  Icon(Icons.star, color: Colors.orange.shade700, size: 20),
                                  SizedBox(width: 8),
                                ],
                                Icon(
                                  Icons.schedule,
                                  color: isSelected
                                      ? (widget.isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700)
                                      : Colors.grey.shade600,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    horario,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? (widget.isDomingoFeriado ? Colors.red.shade900 : Colors.blue.shade900)
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (esSalidaExtra)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'EXTRA',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                if (isSelected)
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: widget.isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: 20),

              // Botón Agregar Nuevo Horario
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context); // Cerrar el diálogo actual
                  final nuevoHorario = await widget.onAgregarNuevo();
                  if (nuevoHorario != null && context.mounted) {
                    // Reabrir el selector con el nuevo horario incluido
                    await Future.delayed(Duration(milliseconds: 100));
                  }
                },
                icon: Icon(Icons.add_alarm, size: 20),
                label: Text(
                  'AGREGAR NUEVO HORARIO',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCELAR (ESC)',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
