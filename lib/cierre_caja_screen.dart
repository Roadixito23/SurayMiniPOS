import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'caja_database.dart';
import 'cierre_caja_report_generator.dart';
import 'shared_widgets.dart';

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
            Card(
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
                    _infoRow(
                      'Último cierre:',
                      _ultimoCierre != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(_ultimoCierre!)
                          : 'No hay cierres previos',
                    ),
                    _infoRow(
                      'Ventas desde último cierre:',
                      '${_ventasDiarias.length}',
                    ),
                    _infoRow(
                      'Total acumulado:',
                      '\$${NumberFormat('#,###').format(_totalBus + _totalCargo)}',
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Resumen por tipo de venta
            Card(
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
                    _buildResumenTipo(
                      'Boletos de Bus',
                      _cantidadBus,
                      _totalBus,
                      Colors.blue.shade600,
                      Icons.directions_bus,
                    ),

                    Divider(height: 32),

                    // Carga
                    _buildResumenTipo(
                      'Carga',
                      _cantidadCargo,
                      _totalCargo,
                      Colors.orange.shade600,
                      Icons.inventory,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Resumen por destino
            if (_destinosBus.isNotEmpty || _destinosCargo.isNotEmpty)
              Card(
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
                            _buildResumenDestino(
                              entry.key,
                              entry.value['cantidad'],
                              entry.value['total'],
                              Colors.blue.shade100,
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
                            _buildResumenDestino(
                              entry.key,
                              entry.value['cantidad'],
                              entry.value['total'],
                              Colors.orange.shade100,
                            ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            SizedBox(height: 24),

            // Observaciones
            Card(
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
            ),

            SizedBox(height: 32),

            // Botón de Cierre de Caja
            SizedBox(
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
            ),

            // Historial de Cierres
            SizedBox(height: 24),
            ElevatedButton.icon(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTipo(
      String titulo,
      int cantidad,
      double total,
      Color color,
      IconData icono,
      ) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          radius: 25,
          child: Icon(
            icono,
            color: color,
            size: 25,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Cantidad: $cantidad',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        Text(
          '\$${NumberFormat('#,###').format(total)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildResumenDestino(
      String destino,
      int cantidad,
      double total,
      Color color,
      ) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destino,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Cantidad: $cantidad',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${NumberFormat('#,###').format(total)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }
}

// Pantalla de historial de cierres
class HistorialCierresScreen extends StatefulWidget {
  @override
  _HistorialCierresScreenState createState() => _HistorialCierresScreenState();
}

class _HistorialCierresScreenState extends State<HistorialCierresScreen> {
  final CajaDatabase _cajaDatabase = CajaDatabase();
  List<Map<String, dynamic>> _cierresCaja = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cierres = await _cajaDatabase.getCierresCaja();

      // Ordenar por fecha (más reciente primero)
      cierres.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      setState(() {
        _cierresCaja = cierres;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar historial: $e')),
      );
    }
  }

  Future<void> _verDetalleCierre(Map<String, dynamic> cierre) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleCierreScreen(cierre: cierre),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Cierres'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _cierresCaja.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 70,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'No hay cierres de caja registrados',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _cierresCaja.length,
        padding: EdgeInsets.all(16.0),
        itemBuilder: (context, index) {
          final cierre = _cierresCaja[index];
          final fecha = cierre['fecha'];
          final hora = cierre['hora'];
          final total = cierre['total'];
          final cantidad = cierre['cantidad'];

          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Icon(Icons.receipt_long, color: Colors.green.shade700),
              ),
              title: Text(
                'Cierre: $fecha',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                  'Hora: $hora - Total: \$${NumberFormat('#,###').format(total)} - Ventas: $cantidad'
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _verDetalleCierre(cierre),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        },
      ),
    );
  }
}

// Pantalla de detalle de cierre
class DetalleCierreScreen extends StatelessWidget {
  final Map<String, dynamic> cierre;

  const DetalleCierreScreen({Key? key, required this.cierre}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fecha = cierre['fecha'];
    final hora = cierre['hora'];
    final totalBus = cierre['totalBus'];
    final totalCargo = cierre['totalCargo'];
    final cantidadBus = cierre['cantidadBus'];
    final cantidadCargo = cierre['cantidadCargo'];
    final usuario = cierre['usuario'];
    final observaciones = cierre['observaciones'];

    // Destinos
    final destinosBus = cierre['destinosBus'] as Map<String, dynamic>?;
    final destinosCargo = cierre['destinosCargo'] as Map<String, dynamic>?;

    // Ventas
    final ventas = cierre['ventas'] as List<dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle de Cierre'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.print),
            onPressed: () => CierreCajaReportGenerator.generateAndPrintReport(cierre),
            tooltip: 'Reimprimir reporte',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información general
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cierre de Caja: $fecha',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 16),
                    _infoRow('Fecha:', fecha),
                    _infoRow('Hora:', hora),
                    _infoRow('Usuario:', usuario),
                    _infoRow('Total Bus:', '\$${NumberFormat('#,###').format(totalBus)}'),
                    _infoRow('Total Cargo:', '\$${NumberFormat('#,###').format(totalCargo)}'),
                    _infoRow('Total General:', '\$${NumberFormat('#,###').format(totalBus + totalCargo)}'),
                    _infoRow('Cantidad Ventas:', '${cantidadBus + cantidadCargo}'),
                    if (observaciones != null && observaciones.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text(
                        'Observaciones:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        observaciones,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Resumen de destinos
            if (destinosBus != null && destinosBus.isNotEmpty ||
                destinosCargo != null && destinosCargo.isNotEmpty)
              Card(
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
                      if (destinosBus != null && destinosBus.isNotEmpty) ...[
                        Text(
                          'Boletos de Bus:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...destinosBus.entries.map((entry) {
                          final destino = entry.key;
                          final data = entry.value as Map<String, dynamic>;
                          final cantidad = data['cantidad'];
                          final total = data['total'];

                          return _buildResumenDestino(
                            destino,
                            cantidad,
                            total,
                            Colors.blue.shade100,
                          );
                        }),
                        SizedBox(height: 16),
                      ],

                      // Destinos de Cargo
                      if (destinosCargo != null && destinosCargo.isNotEmpty) ...[
                        Text(
                          'Carga:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...destinosCargo.entries.map((entry) {
                          final destino = entry.key;
                          final data = entry.value as Map<String, dynamic>;
                          final cantidad = data['cantidad'];
                          final total = data['total'];

                          return _buildResumenDestino(
                            destino,
                            cantidad,
                            total,
                            Colors.orange.shade100,
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),

            SizedBox(height: 24),

            // Detalle de ventas
            if (ventas != null && ventas.isNotEmpty)
              Card(
                elevation: 3,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Detalle de Ventas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            'Total: ${ventas.length}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Lista de ventas
                      for (var venta in ventas) _buildVentaItem(venta),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenDestino(
      String destino,
      int cantidad,
      double total,
      Color color,
      ) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destino,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Cantidad: $cantidad',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${NumberFormat('#,###').format(total)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVentaItem(Map<String, dynamic> venta) {
    final esBus = venta['tipo'] == 'bus';
    final valor = venta['valor'];
    final comprobante = venta['comprobante'];
    final hora = venta['hora'];

    String detalle;
    IconData icono;
    Color color;

    if (esBus) {
      final destino = venta['destino'];
      final asiento = venta['asiento'];
      detalle = 'Bus a $destino - Asiento $asiento';
      icono = Icons.directions_bus;
      color = Colors.blue.shade700;
    } else {
      final destino = venta['destino'];
      final articulo = venta['articulo'];
      detalle = 'Cargo a $destino - $articulo';
      icono = Icons.inventory;
      color = Colors.orange.shade700;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icono, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Comp: $comprobante - Hora: $hora',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${NumberFormat('#,###').format(valor)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}