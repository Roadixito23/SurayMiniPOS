import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/caja_database.dart';
import '../services/cierre_caja_report_generator.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/cierre_caja_widgets.dart';
import 'historial_cierres_screen.dart';

class CierreCajaScreen extends StatefulWidget {
  @override
  _CierreCajaScreenState createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  final CajaDatabase _cajaDatabase = CajaDatabase();
  List<Map<String, dynamic>> _ventasDiarias = [];
  bool _isLoading = true;
  DateTime? _ultimoCierre;
  TextEditingController _observacionesController = TextEditingController();

  // Resumen de ventas
  double _totalBus = 0;
  double _totalCargo = 0;
  int _cantidadBus = 0;
  int _cantidadCargo = 0;
  Map<String, Map<String, dynamic>> _destinosBus = {};
  Map<String, Map<String, dynamic>> _destinosCargo = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar ventas desde el último cierre
      final ventas = await _cajaDatabase.getVentasDiarias();
      // Obtener la fecha del último cierre
      final ultimoCierre = await _cajaDatabase.getUltimoCierre();

      // Procesar ventas para obtener totales
      double totalBus = 0;
      double totalCargo = 0;
      int cantidadBus = 0;
      int cantidadCargo = 0;
      Map<String, Map<String, dynamic>> destinosBus = {};
      Map<String, Map<String, dynamic>> destinosCargo = {};

      for (var venta in ventas) {
        if (venta['tipo'] == 'bus') {
          totalBus += venta['valor'];
          cantidadBus++;

          // Agrupar por destino (bus)
          final destino = venta['destino'];
          if (!destinosBus.containsKey(destino)) {
            destinosBus[destino] = {'cantidad': 0, 'total': 0.0};
          }
          destinosBus[destino]!['cantidad'] = destinosBus[destino]!['cantidad'] + 1;
          destinosBus[destino]!['total'] = destinosBus[destino]!['total'] + venta['valor'];
        } else if (venta['tipo'] == 'cargo') {
          totalCargo += venta['valor'];
          cantidadCargo++;

          // Agrupar por destino (cargo)
          final destino = venta['destino'];
          if (!destinosCargo.containsKey(destino)) {
            destinosCargo[destino] = {'cantidad': 0, 'total': 0.0};
          }
          destinosCargo[destino]!['cantidad'] = destinosCargo[destino]!['cantidad'] + 1;
          destinosCargo[destino]!['total'] = destinosCargo[destino]!['total'] + venta['valor'];
        }
      }

      setState(() {
        _ventasDiarias = ventas;
        _ultimoCierre = ultimoCierre;
        _totalBus = totalBus;
        _totalCargo = totalCargo;
        _cantidadBus = cantidadBus;
        _cantidadCargo = cantidadCargo;
        _destinosBus = destinosBus;
        _destinosCargo = destinosCargo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  Future<void> _realizarCierreCaja() async {
    // Verificar si hay ventas para cerrar
    if (_ventasDiarias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay ventas para realizar el cierre de caja')),
      );
      return;
    }

    // Pedir confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: 'Confirmar Cierre de Caja',
        content: 'Esta acción generará un reporte de cierre con ${_ventasDiarias.length} '
            'ventas por un total de \$${NumberFormat('#,###').format(_totalBus + _totalCargo)}. '
            '¿Desea continuar?',
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Realizar cierre de caja
      final cierre = await _cajaDatabase.realizarCierreCaja(
        usuario: 'Administrador', // En un sistema real, se obtendría el usuario actual
        observaciones: _observacionesController.text,
      );

      // Generar reporte PDF
      await CierreCajaReportGenerator.generateAndPrintReport(cierre);

      // Refrescar datos
      await _cargarDatos();

      // Limpiar campo de observaciones
      _observacionesController.clear();

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cierre de caja realizado con éxito'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al realizar cierre de caja: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cierre de Caja'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Refrescar datos',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del último cierre
            _buildInformacionCajaCard(),

            SizedBox(height: 24),

            // Resumen por tipo de venta
            _buildResumenTipoCard(),

            SizedBox(height: 24),

            // Resumen por destino
            if (_destinosBus.isNotEmpty || _destinosCargo.isNotEmpty)
              _buildVentasPorDestinoCard(),

            SizedBox(height: 24),

            // Observaciones
            _buildObservacionesCard(),

            SizedBox(height: 32),

            // Botón de Cierre de Caja
            _buildCierreCajaButton(),

            // Historial de Cierres
            SizedBox(height: 24),
            _buildHistorialButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInformacionCajaCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información de Caja',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            InfoRow(
              label: 'Último cierre:',
              value: _ultimoCierre != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(_ultimoCierre!)
                  : 'No hay cierres previos',
            ),
            InfoRow(
              label: 'Ventas desde último cierre:',
              value: '${_ventasDiarias.length}',
            ),
            InfoRow(
              label: 'Total acumulado:',
              value: '\$${NumberFormat('#,###').format(_totalBus + _totalCargo)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenTipoCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen por Tipo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),

            // Boletos de Bus
            ResumenTipoWidget(
              titulo: 'Boletos de Bus',
              cantidad: _cantidadBus,
              total: _totalBus,
              color: Colors.blue.shade600,
              icono: Icons.directions_bus,
            ),

            Divider(height: 32),

            // Carga
            ResumenTipoWidget(
              titulo: 'Carga',
              cantidad: _cantidadCargo,
              total: _totalCargo,
              color: Colors.orange.shade600,
              icono: Icons.inventory,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVentasPorDestinoCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ventas por Destino',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),

            // Destinos de Bus
            if (_destinosBus.isNotEmpty) ...[
              Text(
                'Boletos de Bus:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              ..._destinosBus.entries.map((entry) =>
                  ResumenDestinoWidget(
                    destino: entry.key,
                    cantidad: entry.value['cantidad'],
                    total: entry.value['total'],
                    color: Colors.blue.shade100,
                  ),
              ),
              SizedBox(height: 16),
            ],

            // Destinos de Cargo
            if (_destinosCargo.isNotEmpty) ...[
              Text(
                'Carga:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              ..._destinosCargo.entries.map((entry) =>
                  ResumenDestinoWidget(
                    destino: entry.key,
                    cantidad: entry.value['cantidad'],
                    total: entry.value['total'],
                    color: Colors.orange.shade100,
                  ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildObservacionesCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Observaciones (Opcional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _observacionesController,
              decoration: InputDecoration(
                hintText: 'Ingrese observaciones para el cierre (Ejemplo, razón del uso de emergencia o Secretario(a) a cargo)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCierreCajaButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _ventasDiarias.isEmpty ? null : _realizarCierreCaja,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
        ),
        child: Text(
          'REALIZAR CIERRE DE CAJA',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHistorialButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistorialCierresScreen(),
          ),
        );
      },
      icon: Icon(Icons.history),
      label: Text('Ver Historial de Cierres'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        minimumSize: Size(double.infinity, 50),
      ),
    );
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }
}
