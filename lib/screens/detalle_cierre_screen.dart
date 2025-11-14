import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/auth_provider.dart';
import '../services/cierre_caja_report_generator.dart';
import '../widgets/cierre_caja_widgets.dart';

/// Pantalla de detalle de un cierre de caja
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
            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              CierreCajaReportGenerator.generateAndPrintReport(
                cierre,
                idSecretario: authProvider.idSecretario,
                sucursalOrigen: authProvider.sucursalActual,
              );
            },
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
                    InfoRow(label: 'Fecha:', value: fecha),
                    InfoRow(label: 'Hora:', value: hora),
                    InfoRow(label: 'Usuario:', value: usuario),
                    InfoRow(label: 'Total Bus:', value: '\$${NumberFormat('#,###').format(totalBus)}'),
                    InfoRow(label: 'Total Cargo:', value: '\$${NumberFormat('#,###').format(totalCargo)}'),
                    InfoRow(label: 'Total General:', value: '\$${NumberFormat('#,###').format(totalBus + totalCargo)}'),
                    InfoRow(label: 'Cantidad Ventas:', value: '${cantidadBus + cantidadCargo}'),
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

                          return ResumenDestinoWidget(
                            destino: destino,
                            cantidad: cantidad,
                            total: total,
                            color: Colors.blue.shade100,
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

                          return ResumenDestinoWidget(
                            destino: destino,
                            cantidad: cantidad,
                            total: total,
                            color: Colors.orange.shade100,
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
                      for (var venta in ventas)
                        VentaItemWidget(venta: venta),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
