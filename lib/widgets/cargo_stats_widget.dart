import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CargoStatsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cargoReceipts;
  final bool isLoading;

  const CargoStatsWidget({
    Key? key,
    required this.cargoReceipts,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (cargoReceipts.isEmpty) {
      return Container();
    }

    // Calcular estadísticas
    final int totalItems = cargoReceipts.length;
    final double totalValue = cargoReceipts.fold(0.0, (sum, item) => sum + (item['precio'] as num).toDouble());

    // Calcular cargos por destino
    final Map<String, int> cargosByDestination = {};
    for (var receipt in cargoReceipts) {
      final destino = receipt['destino'] as String? ?? 'No especificado';
      cargosByDestination[destino] = (cargosByDestination[destino] ?? 0) + 1;
    }

    // Calcular cargos en los últimos 7 días
    final DateTime now = DateTime.now();
    final DateTime oneWeekAgo = now.subtract(Duration(days: 7));
    final int recentCargos = cargoReceipts.where((receipt) {
      final timestamp = receipt['timestamp'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return date.isAfter(oneWeekAgo);
    }).length;

    // Formatear valores monetarios
    final currencyFormat = NumberFormat('#,###', 'es_CL');

    return Card(
      elevation: 4,
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Carga',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
            SizedBox(height: 16),

            // Estadísticas principales
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  'Total de cargos',
                  '$totalItems',
                  Icons.inventory_2_outlined,
                  Colors.blue,
                ),
                _buildStatItem(
                  context,
                  'Valor total',
                  '\$${currencyFormat.format(totalValue)}',
                  Icons.payments_outlined,
                  Colors.green,
                ),
                _buildStatItem(
                  context,
                  'Última semana',
                  '$recentCargos',
                  Icons.date_range,
                  Colors.purple,
                ),
              ],
            ),

            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),

            // Destinos principales
            if (cargosByDestination.isNotEmpty) ...[
              Text(
                'Cargos por Destino:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cargosByDestination.entries.map((entry) {
                  return Chip(
                    label: Text('${entry.key}: ${entry.value}'),
                    backgroundColor: Colors.orange.shade100,
                    avatar: CircleAvatar(
                      backgroundColor: Colors.orange.shade700,
                      child: Text(
                        entry.value.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            icon,
            color: color,
            size: 30,
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}