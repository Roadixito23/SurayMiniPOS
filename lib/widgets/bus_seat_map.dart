import 'package:flutter/material.dart';

enum SeatStatus {
  available, // Verde
  occupied,  // Rojo
  selected,  // Gris
}

class BusSeatMap extends StatelessWidget {
  final int? selectedSeat;
  final Set<int> occupiedSeats;
  final Function(int) onSeatTap;

  const BusSeatMap({
    Key? key,
    this.selectedSeat,
    required this.occupiedSeats,
    required this.onSeatTap,
  }) : super(key: key);

  SeatStatus _getSeatStatus(int seatNumber) {
    if (selectedSeat == seatNumber) {
      return SeatStatus.selected;
    }
    if (occupiedSeats.contains(seatNumber)) {
      return SeatStatus.occupied;
    }
    return SeatStatus.available;
  }

  Color _getSeatColor(SeatStatus status) {
    switch (status) {
      case SeatStatus.available:
        return Colors.green;
      case SeatStatus.occupied:
        return Colors.red;
      case SeatStatus.selected:
        return Colors.grey;
    }
  }

  Widget _buildSeat(int seatNumber, {bool isWindowSeat = false}) {
    final status = _getSeatStatus(seatNumber);
    final color = _getSeatColor(status);
    final isOccupied = status == SeatStatus.occupied;

    return GestureDetector(
      onTap: isOccupied ? null : () => onSeatTap(seatNumber),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isWindowSeat ? Colors.blue.withOpacity(0.3) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            seatNumber.toString().padLeft(2, '0'),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(int seatLeft, int seatRight) {
    // Número impar = ventana (izquierda), par = pasillo (derecha)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(seatLeft, isWindowSeat: true), // Ventana (impar)
        const SizedBox(width: 8), // Pasillo
        _buildSeat(seatRight), // Pasillo (par)
      ],
    );
  }

  Widget _buildLastRow() {
    // Fila especial: 40, 41, 42, 45, 43, 44
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(40),
        _buildSeat(41),
        _buildSeat(42),
        const SizedBox(width: 16), // Espacio para el 45
        _buildSeat(45), // En el medio
        const SizedBox(width: 16),
        _buildSeat(43),
        _buildSeat(44),
      ],
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Colors.green, 'Disponible'),
          const SizedBox(width: 16),
          _buildLegendItem(Colors.red, 'Ocupado'),
          const SizedBox(width: 16),
          _buildLegendItem(Colors.grey, 'Seleccionado'),
          const SizedBox(width: 16),
          Container(
            width: 30,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
            ),
          ),
          const SizedBox(width: 4),
          const Text('Ventana', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'MAPA DE ASIENTOS DEL BUS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '45 asientos disponibles',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 12),
          // Asientos del 1 al 39 (en filas de 2)
          ...List.generate(19, (index) {
            final seatLeft = index * 2 + 1;  // Impares (ventana)
            final seatRight = index * 2 + 2; // Pares (pasillo)
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _buildRow(seatLeft, seatRight),
            );
          }),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Última fila',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          _buildLastRow(),
        ],
      ),
    );
  }
}
