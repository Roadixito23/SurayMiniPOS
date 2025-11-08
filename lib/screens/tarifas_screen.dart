import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/app_database.dart';
import '../models/tarifa.dart';
import '../models/comprobante.dart';

class TarifasScreen extends StatefulWidget {
  const TarifasScreen({super.key});

  @override
  State<TarifasScreen> createState() => _TarifasScreenState();
}

class _TarifasScreenState extends State<TarifasScreen> {
  List<Tarifa> _tarifasLunesASabado = [];
  List<Tarifa> _tarifasDomingoFeriado = [];
  int _currentIndexLunes = 0;
  int _currentIndexDomingo = 0;
  bool _isLoading = true;
  String _tipoDiaActual = 'LUNES A SÁBADO';

  @override
  void initState() {
    super.initState();
    _loadTarifas();
  }

  Future<void> _loadTarifas() async {
    setState(() => _isLoading = true);
    try {
      final tarifasLunes = await AppDatabase.instance.getTarifasByTipoDia('LUNES A SÁBADO');
      final tarifasDomingo = await AppDatabase.instance.getTarifasByTipoDia('DOMINGO / FERIADO');

      setState(() {
        _tarifasLunesASabado = tarifasLunes.map((map) => Tarifa.fromMap(map)).toList();
        _tarifasDomingoFeriado = tarifasDomingo.map((map) => Tarifa.fromMap(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tarifas: $e')),
        );
      }
    }
  }

  List<Tarifa> get _currentList =>
      _tipoDiaActual == 'LUNES A SÁBADO' ? _tarifasLunesASabado : _tarifasDomingoFeriado;

  int get _currentIndex =>
      _tipoDiaActual == 'LUNES A SÁBADO' ? _currentIndexLunes : _currentIndexDomingo;

  set _currentIndex(int value) {
    if (_tipoDiaActual == 'LUNES A SÁBADO') {
      _currentIndexLunes = value;
    } else {
      _currentIndexDomingo = value;
    }
  }

  void _navigatePrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex = _currentIndex - 1;
      });
    }
  }

  void _navigateNext() {
    if (_currentIndex < _currentList.length - 1) {
      setState(() {
        _currentIndex = _currentIndex + 1;
      });
    }
  }

  void _toggleTipoDia() {
    setState(() {
      _tipoDiaActual = _tipoDiaActual == 'LUNES A SÁBADO' ? 'DOMINGO / FERIADO' : 'LUNES A SÁBADO';
    });
  }

  Future<void> _editarTarifa(Tarifa tarifa) async {
    final controller = TextEditingController(text: tarifa.valor.toStringAsFixed(0));

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar ${tarifa.categoria}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tipo de día: ${tarifa.tipoDia}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = double.tryParse(controller.text);
              if (valor != null && valor > 0) {
                Navigator.pop(context, valor);
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );

    if (result != null && tarifa.id != null) {
      try {
        await AppDatabase.instance.updateTarifa(
          tarifa.id!,
          tarifa.copyWith(valor: result).toMap(),
        );
        await _loadTarifas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarifa actualizada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar tarifa: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión de Tarifas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión de Tarifas')),
        body: const Center(
          child: Text('No hay tarifas disponibles'),
        ),
      );
    }

    final currentTarifa = _currentList[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Tarifas'),
        actions: [
          // Botón para cambiar entre tipos de día
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Cambiar tipo de día',
            onPressed: _toggleTipoDia,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botón Anterior
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: _currentIndex > 0 ? _navigatePrevious : null,
                  tooltip: 'Anterior',
                ),
                const SizedBox(width: 16),
                // Indicador de posición y tipo de día
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tipoDiaActual,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentIndex + 1} / ${_currentList.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Botón Siguiente
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  onPressed: _currentIndex < _currentList.length - 1 ? _navigateNext : null,
                  tooltip: 'Siguiente',
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Card principal con información de la tarifa
            Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo de día
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF1976D2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TIPO DE DÍA',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentTarifa.tipoDia,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    // Categoría
                    Row(
                      children: [
                        const Icon(Icons.category, color: Color(0xFF1976D2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CATEGORÍA',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentTarifa.categoria,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    // Valor
                    Row(
                      children: [
                        const Icon(Icons.attach_money, color: Color(0xFF1976D2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'VALOR',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${currentTarifa.valor.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Botón de editar
                        ElevatedButton.icon(
                          onPressed: () => _editarTarifa(currentTarifa),
                          icon: const Icon(Icons.edit),
                          label: const Text('EDITAR'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    // Último comprobante vendido
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Color(0xFF1976D2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ÚLTIMO N° DE COMPROBANTE',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<String>(
                                future: ComprobanteManager().getLastSoldComprobante(currentTarifa.categoria),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Text(
                                      'Cargando...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  }

                                  final comprobante = snapshot.data ?? 'Sin ventas';
                                  final color = comprobante == 'Sin ventas'
                                      ? Colors.grey
                                      : const Color(0xFF1976D2);

                                  return Text(
                                    comprobante,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Instrucciones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1976D2)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Use las flechas en la parte superior para navegar entre tarifas. '
                      'Use el ícono de calendario para cambiar entre días laborales y feriados.',
                      style: TextStyle(fontSize: 13),
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
}
