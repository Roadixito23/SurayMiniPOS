import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/app_database.dart';
import '../models/tarifa.dart';
import '../models/comprobante.dart';
import '../widgets/color_picker_dialog.dart';

class TarifasScreen extends StatefulWidget {
  const TarifasScreen({super.key});

  @override
  State<TarifasScreen> createState() => _TarifasScreenState();
}

class _TarifasScreenState extends State<TarifasScreen> {
  List<Tarifa> _tarifasPuntoAPunto = [];
  List<Tarifa> _tarifasIntermedios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTarifas();
  }

  Future<void> _loadTarifas() async {
    setState(() => _isLoading = true);
    try {
      final todasTarifas = await AppDatabase.instance.getAllTarifas();
      final tarifas = todasTarifas.map((map) => Tarifa.fromMap(map)).toList();

      setState(() {
        // Separar punto a punto de intermedios
        _tarifasPuntoAPunto = tarifas
            .where((t) => !t.categoria.toUpperCase().contains('INTERMEDIO'))
            .toList();
        _tarifasIntermedios = tarifas
            .where((t) => t.categoria.toUpperCase().contains('INTERMEDIO'))
            .toList();
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

  Future<void> _editarValor(Tarifa tarifa) async {
    final controller = TextEditingController(text: tarifa.valor.toStringAsFixed(0));

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Valor - ${tarifa.categoria}'),
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

  Future<void> _editarColor(Tarifa tarifa) async {
    // Color inicial: si tiene color asignado, usarlo; si no, azul por defecto
    Color initialColor = tarifa.color != null
        ? Color(int.parse(tarifa.color!, radix: 16))
        : Colors.blue;

    final result = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: initialColor),
    );

    if (result != null && tarifa.id != null) {
      try {
        // Convertir color a string hex
        String colorHex = result.value.toRadixString(16).padLeft(8, '0').toUpperCase();

        await AppDatabase.instance.updateTarifa(
          tarifa.id!,
          tarifa.copyWith(color: colorHex).toMap(),
        );
        await _loadTarifas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Color actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar color: $e')),
          );
        }
      }
    }
  }

  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.blue;
    }
    try {
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.blue;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Tarifas'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadTarifas,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      'Configure los precios para cada tipo de boleto y día de la semana. '
                      'Puede personalizar el color de cada tarifa para identificarlas fácilmente en estadísticas.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sección: Boletos Punto a Punto
            _buildSeccionTarifas(
              titulo: 'Boletos Punto a Punto',
              icono: Icons.route,
              color: Colors.blue,
              tarifas: _tarifasPuntoAPunto,
            ),

            const SizedBox(height: 32),

            // Sección: Boletos Intermedios
            _buildSeccionTarifas(
              titulo: 'Boletos de Oferta Intermedio',
              icono: Icons.location_on,
              color: Colors.orange,
              tarifas: _tarifasIntermedios,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTarifas({
    required String titulo,
    required IconData icono,
    required Color color,
    required List<Tarifa> tarifas,
  }) {
    if (tarifas.isEmpty) {
      return const SizedBox.shrink();
    }

    // Agrupar por categoría
    Map<String, List<Tarifa>> tarifasPorCategoria = {};
    for (var tarifa in tarifas) {
      if (!tarifasPorCategoria.containsKey(tarifa.categoria)) {
        tarifasPorCategoria[tarifa.categoria] = [];
      }
      tarifasPorCategoria[tarifa.categoria]!.add(tarifa);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Row(
          children: [
            Icon(icono, color: color, size: 32),
            const SizedBox(width: 12),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Cards de tarifas por categoría
        ...tarifasPorCategoria.entries.map((entry) {
          String categoria = entry.key;
          List<Tarifa> tarifasCategoria = entry.value;

          // Separar por tipo de día
          Tarifa? tarifaLunesASabado = tarifasCategoria.firstWhere(
            (t) => t.tipoDia == 'LUNES A SÁBADO',
            orElse: () => tarifasCategoria.first,
          );
          Tarifa? tarifaDomingoFeriado = tarifasCategoria.firstWhere(
            (t) => t.tipoDia == 'DOMINGO / FERIADO',
            orElse: () => tarifasCategoria.first,
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildTarifaCard(
              categoria: categoria,
              tarifaLunesASabado: tarifaLunesASabado,
              tarifaDomingoFeriado: tarifaDomingoFeriado,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTarifaCard({
    required String categoria,
    required Tarifa tarifaLunesASabado,
    required Tarifa tarifaDomingoFeriado,
  }) {
    Color categoriaColor = _getColorFromHex(tarifaLunesASabado.color);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header con categoría y selector de color
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: categoriaColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: categoriaColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    categoria,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: categoriaColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.palette),
                  tooltip: 'Cambiar color',
                  onPressed: () => _editarColor(tarifaLunesASabado),
                  color: categoriaColor,
                ),
              ],
            ),
          ),

          // Contenido con los dos tipos de día
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Lunes a Sábado
                Expanded(
                  child: _buildDiaCard(
                    tipoDia: 'LUNES A SÁBADO',
                    tarifa: tarifaLunesASabado,
                    icon: Icons.calendar_today,
                    iconColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                // Domingo / Feriado
                Expanded(
                  child: _buildDiaCard(
                    tipoDia: 'DOMINGO / FERIADO',
                    tarifa: tarifaDomingoFeriado,
                    icon: Icons.event,
                    iconColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaCard({
    required String tipoDia,
    required Tarifa tarifa,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tipoDia,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Valor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VALOR',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${tarifa.valor.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Editar valor',
                onPressed: () => _editarValor(tarifa),
                color: iconColor,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Último comprobante
          const Text(
            'ÚLTIMO COMPROBANTE',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          FutureBuilder<String>(
            future: ComprobanteManager().getLastSoldComprobante(tarifa.categoria),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  'Cargando...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                );
              }

              final comprobante = snapshot.data ?? 'Sin ventas';
              final color = comprobante == 'Sin ventas' ? Colors.grey : iconColor;

              return Text(
                comprobante,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
