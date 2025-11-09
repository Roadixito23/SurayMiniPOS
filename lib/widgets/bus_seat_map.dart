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
  final String tipoDia; // Para animaciones de color

  const BusSeatMap({
    Key? key,
    this.selectedSeat,
    required this.occupiedSeats,
    required this.onSeatTap,
    this.tipoDia = 'LUNES A SÁBADO',
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
    final isDomingoFeriado = tipoDia == 'DOMINGO / FERIADO';

    switch (status) {
      case SeatStatus.available:
        return isDomingoFeriado
          ? Colors.red.shade100  // Rojo pastel para domingo/feriado
          : Colors.blue.shade100; // Azul pastel para lunes-sábado
      case SeatStatus.occupied:
        return isDomingoFeriado
          ? Colors.red.shade400
          : Colors.blue.shade400;
      case SeatStatus.selected:
        return Colors.grey.shade600;
    }
  }

  Widget _buildSeat(int seatNumber, {bool isWindowSeat = false}) {
    final status = _getSeatStatus(seatNumber);
    final color = _getSeatColor(status);
    final isOccupied = status == SeatStatus.occupied;
    final isDomingoFeriado = tipoDia == 'DOMINGO / FERIADO';

    return GestureDetector(
      onTap: isOccupied ? null : () => onSeatTap(seatNumber),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: isWindowSeat
            ? Border.all(
                color: isDomingoFeriado
                  ? Colors.red.shade300
                  : Colors.blue.shade300,
                width: 2,
              )
            : null,
          boxShadow: status == SeatStatus.available
            ? [
                BoxShadow(
                  color: (isDomingoFeriado ? Colors.red : Colors.blue).withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        ),
        child: Center(
          child: Text(
            seatNumber.toString().padLeft(2, '0'),
            style: TextStyle(
              color: status == SeatStatus.available
                ? (isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700)
                : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow4Seats(int seat1, int seat2, int seat3, int seat4) {
    // Layout: [1-ventana] [2-pasillo]  PASILLO  [4-pasillo] [3-ventana]
    // Los impares (1,3,5,7...) van en las ventanas (lados exteriores)
    // Los pares (2,4,6,8...) van en los pasillos (lados interiores)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(seat1, isWindowSeat: true), // Ventana izquierda (impar)
        _buildSeat(seat2), // Pasillo izquierdo (par)
        const SizedBox(width: 20), // Pasillo central
        _buildSeat(seat4), // Pasillo derecho (par)
        _buildSeat(seat3, isWindowSeat: true), // Ventana derecha (impar)
      ],
    );
  }

  Widget _buildLastRow() {
    // Última fila especial: 5 asientos (41, 42, 43, 44, 45)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(41, isWindowSeat: true),
        _buildSeat(42),
        _buildSeat(43),
        _buildSeat(44),
        _buildSeat(45, isWindowSeat: true),
      ],
    );
  }

  Widget _buildLegend() {
    final isDomingoFeriado = tipoDia == 'DOMINGO / FERIADO';
    final availableColor = isDomingoFeriado ? Colors.red.shade100 : Colors.blue.shade100;
    final occupiedColor = isDomingoFeriado ? Colors.red.shade400 : Colors.blue.shade400;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(availableColor, 'Disponible'),
          const SizedBox(width: 16),
          _buildLegendItem(occupiedColor, 'Ocupado'),
          const SizedBox(width: 16),
          _buildLegendItem(Colors.grey.shade600, 'Seleccionado'),
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
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDomingoFeriado = tipoDia == 'DOMINGO / FERIADO';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isDomingoFeriado ? Colors.red : Colors.blue).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_bus,
                color: isDomingoFeriado ? Colors.red.shade600 : Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'MAPA DE ASIENTOS DEL BUS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '45 asientos disponibles',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 12),
          // Asientos del 1 al 40 (en filas de 4)
          ...List.generate(10, (index) {
            final seat1 = index * 4 + 1;  // 1, 5, 9, 13, ...
            final seat2 = index * 4 + 2;  // 2, 6, 10, 14, ...
            final seat3 = index * 4 + 3;  // 3, 7, 11, 15, ...
            final seat4 = index * 4 + 4;  // 4, 8, 12, 16, ...
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _buildRow4Seats(seat1, seat2, seat3, seat4),
            );
          }),
          const SizedBox(height: 12),
          Divider(color: isDomingoFeriado ? Colors.red.shade200 : Colors.blue.shade200),
          const SizedBox(height: 8),
          Text(
            'Última fila',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDomingoFeriado ? Colors.red.shade600 : Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 8),
          _buildLastRow(),
        ],
      ),
    );
  }
}
