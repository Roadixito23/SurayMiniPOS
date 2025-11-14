import 'package:flutter/material.dart';

enum SeatStatus {
  available,
  occupied,
  selected,
}

class BusSeatMap extends StatefulWidget {
  final int? selectedSeat;
  final Set<int> occupiedSeats;
  final Function(int) onSeatTap;
  final String tipoDia;
  final int capacity; // Capacidad del bus: 20, 35, 41, 45, 46

  const BusSeatMap({
    Key? key,
    this.selectedSeat,
    required this.occupiedSeats,
    required this.onSeatTap,
    this.tipoDia = 'LUNES A SÁBADO',
    this.capacity = 45,
  }) : super(key: key);

  @override
  _BusSeatMapState createState() => _BusSeatMapState();
}

class _BusSeatMapState extends State<BusSeatMap> {
  int _capacity = 45;

  @override
  void initState() {
    super.initState();
    _capacity = widget.capacity;
  }

  SeatStatus _getSeatStatus(int seatNumber) {
    if (widget.selectedSeat == seatNumber) {
      return SeatStatus.selected;
    }
    if (widget.occupiedSeats.contains(seatNumber)) {
      return SeatStatus.occupied;
    }
    return SeatStatus.available;
  }

  Color _getSeatColor(SeatStatus status) {
    final isDomingoFeriado = widget.tipoDia == 'DOMINGO / FERIADO';

    switch (status) {
      case SeatStatus.available:
        // Colores pastel según tipo de día
        return isDomingoFeriado
          ? Colors.red.shade100
          : Colors.blue.shade100;
      case SeatStatus.occupied:
        // Asientos ocupados siempre en gris
        return Colors.grey.shade400;
      case SeatStatus.selected:
        // Asientos seleccionados en tono más oscuro de los colores pastel
        return isDomingoFeriado
          ? Colors.red.shade300
          : Colors.blue.shade300;
    }
  }

  Widget _buildSeat(int seatNumber, {bool isWindowSeat = false}) {
    final status = _getSeatStatus(seatNumber);
    final color = _getSeatColor(status);
    final isOccupied = status == SeatStatus.occupied;
    final isDomingoFeriado = widget.tipoDia == 'DOMINGO / FERIADO';

    return GestureDetector(
      onTap: isOccupied ? null : () => widget.onSeatTap(seatNumber),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: isWindowSeat
            ? Border.all(
                color: isDomingoFeriado
                  ? Colors.red.shade400
                  : Colors.blue.shade400,
                width: 2,
              )
            : null,
          boxShadow: status == SeatStatus.available
            ? [
                BoxShadow(
                  color: (isDomingoFeriado ? Colors.red : Colors.blue).withOpacity(0.2),
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
              color: status == SeatStatus.occupied
                ? Colors.white
                : (isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // Construir filas según la configuración
  List<Widget> _buildSeatRows() {
    List<Widget> rows = [];

    switch (_capacity) {
      case 20:
        // 20 asientos: solo pares (en el pasillo), omitir final de 5
        // Asientos pares: 2, 4, 6, 8, ... hasta 20
        // 4 columnas por fila
        for (int i = 0; i < 5; i++) {
          rows.add(_buildRow4Seats(
            i * 4 + 1,  // ventana izq
            i * 4 + 2,  // pasillo izq
            i * 4 + 3,  // ventana der
            i * 4 + 4,  // pasillo der
          ));
        }
        break;

      case 35:
        // 35 asientos: asiento del medio como central (igual que 45)
        // 8 filas de 4 (32) + última fila de 3 (central)
        for (int i = 0; i < 8; i++) {
          rows.add(_buildRow4Seats(
            i * 4 + 1,
            i * 4 + 2,
            i * 4 + 3,
            i * 4 + 4,
          ));
        }
        rows.add(const SizedBox(height: 12));
        rows.add(const Divider());
        rows.add(const SizedBox(height: 8));
        rows.add(_buildLastRow35());
        break;

      case 41:
        // 41 asientos: misma lógica que 35
        // 9 filas de 4 (36) + última fila de 5
        for (int i = 0; i < 9; i++) {
          rows.add(_buildRow4Seats(
            i * 4 + 1,
            i * 4 + 2,
            i * 4 + 3,
            i * 4 + 4,
          ));
        }
        rows.add(const SizedBox(height: 12));
        rows.add(const Divider());
        rows.add(const SizedBox(height: 8));
        rows.add(_buildLastRow41());
        break;

      case 45:
        // 45 asientos: lógica actual
        // 10 filas de 4 (40) + última fila de 5
        for (int i = 0; i < 10; i++) {
          rows.add(_buildRow4Seats(
            i * 4 + 1,
            i * 4 + 2,
            i * 4 + 3,
            i * 4 + 4,
          ));
        }
        rows.add(const SizedBox(height: 12));
        rows.add(const Divider());
        rows.add(const SizedBox(height: 8));
        rows.add(_buildLastRow45());
        break;

      case 46:
        // 46 asientos: misma lógica del bus de 20 (solo pares)
        // 11 filas de 4 + última fila de 2
        for (int i = 0; i < 11; i++) {
          rows.add(_buildRow4Seats(
            i * 4 + 1,
            i * 4 + 2,
            i * 4 + 3,
            i * 4 + 4,
          ));
        }
        rows.add(const SizedBox(height: 12));
        rows.add(const Divider());
        rows.add(const SizedBox(height: 8));
        rows.add(_buildLastRow46());
        break;

      default:
        rows.add(Text('Configuración no soportada'));
    }

    return rows;
  }

  Widget _buildRow4Seats(int seat1, int seat2, int seat3, int seat4) {
    // Layout: [1-ventana] [2-pasillo]  PASILLO  [4-pasillo] [3-ventana]
    // Los impares (1,3,5,7...) van en las ventanas (lados exteriores)
    // Los pares (2,4,6,8...) van en los pasillos (lados interiores)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSeat(seat1, isWindowSeat: true), // Ventana izquierda (impar)
          _buildSeat(seat2), // Pasillo izquierdo (par)
          const SizedBox(width: 30), // Pasillo central
          _buildSeat(seat4), // Pasillo derecho (par)
          _buildSeat(seat3, isWindowSeat: true), // Ventana derecha (impar)
        ],
      ),
    );
  }

  Widget _buildLastRow35() {
    // Última fila para 35 asientos: 33, 34, 35 (centro)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(33, isWindowSeat: true),
        _buildSeat(34),
        _buildSeat(35), // Centro
      ],
    );
  }

  Widget _buildLastRow41() {
    // Última fila para 41 asientos: 37, 38, 39, 40, 41
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(37, isWindowSeat: true),
        _buildSeat(38),
        _buildSeat(39), // Centro
        _buildSeat(40),
        _buildSeat(41, isWindowSeat: true),
      ],
    );
  }

  Widget _buildLastRow45() {
    // Última fila para 45 asientos: 41, 42, 45 en el medio, 43, 44
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(41, isWindowSeat: true),
        _buildSeat(42),
        _buildSeat(45), // Asiento 45 en el medio
        _buildSeat(43),
        _buildSeat(44, isWindowSeat: true),
      ],
    );
  }

  Widget _buildLastRow46() {
    // Última fila para 46 asientos: 45, 46
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(45),
        _buildSeat(46),
      ],
    );
  }

  Widget _buildLegend() {
    final isDomingoFeriado = widget.tipoDia == 'DOMINGO / FERIADO';
    final availableColor = isDomingoFeriado ? Colors.red.shade100 : Colors.blue.shade100;
    final selectedColor = isDomingoFeriado ? Colors.red.shade300 : Colors.blue.shade300;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(availableColor, 'Disponible'),
          const SizedBox(width: 16),
          _buildLegendItem(Colors.grey.shade400, 'Ocupado'),
          const SizedBox(width: 16),
          _buildLegendItem(selectedColor, 'Seleccionado'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDomingoFeriado = widget.tipoDia == 'DOMINGO / FERIADO';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Título y selector de capacidad
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.directions_bus,
                    color: isDomingoFeriado ? Colors.red.shade600 : Colors.blue.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MAPA DE ASIENTOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        'Bus de $_capacity asientos',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Selector de capacidad
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDomingoFeriado ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDomingoFeriado ? Colors.red.shade200 : Colors.blue.shade200,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _capacity,
                    isDense: true,
                    items: [20, 35, 41, 45, 46].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          '$value asientos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _capacity = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 16),

          // Mapa de asientos
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _buildSeatRows(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
