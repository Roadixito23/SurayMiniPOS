import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget para mostrar una fila de información con label y value
class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
}

/// Widget para mostrar el resumen por tipo de venta (Bus o Cargo)
class ResumenTipoWidget extends StatelessWidget {
  final String titulo;
  final int cantidad;
  final double total;
  final Color color;
  final IconData icono;

  const ResumenTipoWidget({
    Key? key,
    required this.titulo,
    required this.cantidad,
    required this.total,
    required this.color,
    required this.icono,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
}

/// Widget para mostrar el resumen por destino
class ResumenDestinoWidget extends StatelessWidget {
  final String destino;
  final int cantidad;
  final double total;
  final Color color;

  const ResumenDestinoWidget({
    Key? key,
    required this.destino,
    required this.cantidad,
    required this.total,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
}

/// Widget para mostrar un item individual de venta en el detalle
class VentaItemWidget extends StatelessWidget {
  final Map<String, dynamic> venta;

  const VentaItemWidget({
    Key? key,
    required this.venta,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
