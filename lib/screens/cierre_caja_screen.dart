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

  // Totales por método de pago
  double _totalEfectivo = 0;
  double _totalTarjeta = 0;

  // Gastos
  List<Map<String, dynamic>> _gastosDiarios = [];
  double _totalGastos = 0;
  double _efectivoFinal = 0;

  // Control de caja
  List<Map<String, dynamic>> _controlCaja = [];

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
      // Cargar gastos desde el último cierre
      final gastos = await _cajaDatabase.getGastosDiarios();
      // Obtener la fecha del último cierre
      final ultimoCierre = await _cajaDatabase.getUltimoCierre();

      // Procesar ventas para obtener totales
      double totalBus = 0;
      double totalCargo = 0;
      int cantidadBus = 0;
      int cantidadCargo = 0;
      Map<String, Map<String, dynamic>> destinosBus = {};
      Map<String, Map<String, dynamic>> destinosCargo = {};

      // Totales por método de pago
      double totalEfectivo = 0;
      double totalTarjeta = 0;

      // Control de caja por tipo de boleto
      Map<String, Map<String, dynamic>> controlCaja = {};

      for (var venta in ventas) {
        // Sumar métodos de pago
        totalEfectivo += (venta['montoEfectivo'] ?? 0.0);
        totalTarjeta += (venta['montoTarjeta'] ?? 0.0);

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

          // Control de caja por tipo de boleto
          final tipoBoleto = venta['tipoBoleto'] ?? 'PUBLICO GENERAL';
          final comprobante = venta['comprobante'] ?? '';

          if (!controlCaja.containsKey(tipoBoleto)) {
            controlCaja[tipoBoleto] = {
              'tipo': tipoBoleto,
              'primerComprobante': comprobante,
              'ultimoComprobante': comprobante,
              'cantidad': 0,
              'subtotal': 0.0,
            };
          }

          controlCaja[tipoBoleto]!['ultimoComprobante'] = comprobante;
          controlCaja[tipoBoleto]!['cantidad'] = controlCaja[tipoBoleto]!['cantidad'] + 1;
          controlCaja[tipoBoleto]!['subtotal'] = controlCaja[tipoBoleto]!['subtotal'] + venta['valor'];
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

      // Calcular totales de gastos
      double totalGastos = 0;
      for (var gasto in gastos) {
        totalGastos += (gasto['monto'] ?? 0.0);
      }

      // Efectivo final (restar gastos)
      double efectivoFinal = totalEfectivo - totalGastos;

      setState(() {
        _ventasDiarias = ventas;
        _gastosDiarios = gastos;
        _ultimoCierre = ultimoCierre;
        _totalBus = totalBus;
        _totalCargo = totalCargo;
        _cantidadBus = cantidadBus;
        _cantidadCargo = cantidadCargo;
        _destinosBus = destinosBus;
        _destinosCargo = destinosCargo;
        _totalEfectivo = totalEfectivo;
        _totalTarjeta = totalTarjeta;
        _totalGastos = totalGastos;
        _efectivoFinal = efectivoFinal;
        _controlCaja = controlCaja.values.toList();
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

  Future<void> _agregarGasto() async {
    // Calcular efectivo disponible
    double efectivoDisponible = _totalEfectivo;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ExpenseDialog(
        efectivoDisponible: efectivoDisponible,
      ),
    );

    if (result != null) {
      try {
        await _cajaDatabase.registrarGasto(
          tipoGasto: result['tipoGasto'],
          monto: result['monto'],
          numeroMaquina: result['numeroMaquina'],
          chofer: result['chofer'],
          descripcion: result['descripcion'],
        );

        // Refrescar datos
        await _cargarDatos();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gasto registrado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar gasto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

            // Resumen de pagos por método
            _buildResumenPagosCard(),

            SizedBox(height: 24),

            // Gastos
            _buildGastosCard(),

            SizedBox(height: 24),

            // Control de Caja
            if (_controlCaja.isNotEmpty)
              _buildControlCajaCard(),

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

  Widget _buildResumenPagosCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Pagos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            _buildPaymentRow(
              'Total en Efectivo:',
              _totalEfectivo,
              Colors.green.shade700,
            ),
            SizedBox(height: 8),
            _buildPaymentRow(
              'Total en Tarjeta:',
              _totalTarjeta,
              Colors.blue.shade700,
            ),
            Divider(height: 24),
            _buildPaymentRow(
              'Total Gastos:',
              _totalGastos,
              Colors.red.shade700,
            ),
            Divider(height: 24, thickness: 2),
            _buildPaymentRow(
              'Efectivo Final:',
              _efectivoFinal,
              _efectivoFinal < 0 ? Colors.red.shade700 : Colors.green.shade700,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String label, double amount, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '\$${NumberFormat('#,###').format(amount)}',
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGastosCard() {
    return Card(
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
                  'Gastos del Día',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _agregarGasto,
                  icon: Icon(Icons.add, size: 18),
                  label: Text('Agregar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_gastosDiarios.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No hay gastos registrados',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ..._gastosDiarios.map((gasto) => _buildGastoItem(gasto)),
          ],
        ),
      ),
    );
  }

  Widget _buildGastoItem(Map<String, dynamic> gasto) {
    final tipoGasto = gasto['tipoGasto'] ?? '';
    final monto = gasto['monto'] ?? 0.0;
    final hora = gasto['hora'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    tipoGasto == 'Combustible' ? Icons.local_gas_station : Icons.receipt_long,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    tipoGasto,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${NumberFormat('#,###').format(monto)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          if (tipoGasto == 'Combustible') ...[
            SizedBox(height: 8),
            Text(
              'N° Máquina: ${gasto['numeroMaquina'] ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              'Chofer: ${gasto['chofer'] ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ] else if (tipoGasto == 'Otros') ...[
            SizedBox(height: 8),
            Text(
              'Descripción: ${gasto['descripcion'] ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
          SizedBox(height: 4),
          Text(
            'Hora: $hora',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCajaCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control de Caja por Tipo de Boleto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                border: TableBorder.all(color: Colors.grey.shade400),
                columns: [
                  DataColumn(
                    label: Text(
                      'Tipo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Primer N°',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Último N°',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Cantidad',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Subtotal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    numeric: true,
                  ),
                ],
                rows: _controlCaja.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          constraints: BoxConstraints(maxWidth: 120),
                          child: Text(
                            item['tipo'] ?? '',
                            style: TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatComprobante(item['primerComprobante'] ?? ''),
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatComprobante(item['ultimoComprobante'] ?? ''),
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${item['cantidad'] ?? 0}',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          '\$${NumberFormat('#,###').format(item['subtotal'] ?? 0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatComprobante(String comprobante) {
    // Extraer solo la parte final del comprobante para mejor visualización
    // Ejemplo: "AYS-01-000001" -> "000001"
    if (comprobante.isEmpty) return '';
    final parts = comprobante.split('-');
    return parts.length >= 3 ? parts[2] : comprobante;
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }
}
