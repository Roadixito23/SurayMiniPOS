import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tarifa.dart';

class TarifaSelectorDialog extends StatefulWidget {
  final List<Tarifa> tarifas;
  final Tarifa? tarifaSeleccionada;
  final bool isDomingoFeriado;

  const TarifaSelectorDialog({
    required this.tarifas,
    this.tarifaSeleccionada,
    required this.isDomingoFeriado,
  });

  @override
  _TarifaSelectorDialogState createState() => _TarifaSelectorDialogState();
}

class _TarifaSelectorDialogState extends State<TarifaSelectorDialog> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Si hay una tarifa preseleccionada, empezar en ella
    if (widget.tarifaSeleccionada != null) {
      _selectedIndex = widget.tarifas.indexWhere(
        (t) => t.id == widget.tarifaSeleccionada!.id,
      );
      if (_selectedIndex < 0) _selectedIndex = 0;
    }
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
      _selectedIndex = (_selectedIndex + delta).clamp(0, widget.tarifas.length - 1);
      // Auto-scroll
      if (_scrollController.hasClients) {
        final itemHeight = 70.0;
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
    if (_selectedIndex >= 0 && _selectedIndex < widget.tarifas.length) {
      Navigator.pop(context, widget.tarifas[_selectedIndex]);
    }
  }

  MaterialColor _getCategoriaColor(String categoria) {
    if (categoria.toUpperCase().contains('NORMAL')) {
      return Colors.blue;
    } else if (categoria.toUpperCase().contains('NIÑO') || categoria.toUpperCase().contains('NINO')) {
      return Colors.green;
    } else if (categoria.toUpperCase().contains('EXENTO')) {
      return Colors.purple;
    } else if (categoria.toUpperCase().contains('INTERMEDIO')) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  IconData _getCategoriaIcon(String categoria) {
    if (categoria.toUpperCase().contains('NORMAL')) {
      return Icons.person;
    } else if (categoria.toUpperCase().contains('NIÑO') || categoria.toUpperCase().contains('NINO')) {
      return Icons.child_care;
    } else if (categoria.toUpperCase().contains('EXENTO')) {
      return Icons.card_giftcard;
    } else if (categoria.toUpperCase().contains('INTERMEDIO')) {
      return Icons.location_on;
    }
    return Icons.local_offer;
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
                    Icons.local_offer,
                    color: widget.isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'SELECCIONAR TARIFA',
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

              // Lista de tarifas
              Container(
                constraints: BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  itemCount: widget.tarifas.length,
                  itemBuilder: (context, index) {
                    final tarifa = widget.tarifas[index];
                    final isSelected = index == _selectedIndex;
                    final categoriaColor = _getCategoriaColor(tarifa.categoria);
                    final categoriaIcon = _getCategoriaIcon(tarifa.categoria);

                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: isSelected
                            ? categoriaColor.shade100
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        elevation: isSelected ? 4 : 1,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, tarifa),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? categoriaColor.shade400
                                    : Colors.grey.shade200,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  categoriaIcon,
                                  color: isSelected
                                      ? categoriaColor.shade700
                                      : categoriaColor.shade400,
                                  size: 28,
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tarifa.categoria,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected
                                              ? categoriaColor.shade900
                                              : Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '\$${tarifa.valor.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: categoriaColor.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: categoriaColor.shade700,
                                    size: 24,
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

              SizedBox(height: 16),

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
