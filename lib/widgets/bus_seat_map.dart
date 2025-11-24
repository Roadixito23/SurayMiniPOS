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
    switch (status) {
      case SeatStatus.available:
        // Asientos disponibles siempre verde (mismo tono para LUN-SAB y DOM/FER)
        return Colors.green.shade400;
      case SeatStatus.occupied:
        // Asientos ocupados siempre rojo
        return Colors.red.shade600;
      case SeatStatus.selected:
        // Asientos seleccionados en verde (se mostrará X blanca)
        return Colors.green.shade400;
    }
  }

  Widget _buildSeat(int seatNumber, {bool isWindowSeat = false}) {
    final status = _getSeatStatus(seatNumber);
    final color = _getSeatColor(status);
    final isOccupied = status == SeatStatus.occupied;
    final isSelected = status == SeatStatus.selected;

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
                color: Colors.grey.shade400,
                width: 2,
              )
            : null,
        ),
        child: Center(
          child: isSelected
            ? Stack(
                alignment: Alignment.center,
                children: [
                  // X blanca con bordes negros
                  Text(
                    'X',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 3
                        ..color = Colors.black,
                    ),
                  ),
                  Text(
                    'X',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                ],
              )
            : Text(
                seatNumber.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: status == SeatStatus.occupied
                    ? Colors.white
                    : Colors.green.shade900,
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
        // 35 asientos: Layout especial para simular espacio del chofer
        // Primera fila: solo lado izquierdo (asientos 1, 2)
        rows.add(_buildRow2SeatsLeft(1, 2));
        // Siguientes 6 filas: 4 asientos normales
        for (int i = 1; i < 7; i++) {
          rows.add(_buildRow4Seats(
            i * 4 - 1,  // 3, 7, 11, 15, 19, 23
            i * 4,      // 4, 8, 12, 16, 20, 24
            i * 4 + 1,  // 5, 9, 13, 17, 21, 25
            i * 4 + 2,  // 6, 10, 14, 18, 22, 26
          ));
        }
        // Última fila con 27, 28
        rows.add(_buildRow2SeatsLeft(27, 28));
        rows.add(const SizedBox(height: 12));
        rows.add(const Divider());
        rows.add(const SizedBox(height: 8));
        // Fila final: 29, 30, 31, 32, 33
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

  Widget _buildRow2SeatsLeft(int seat1, int seat2) {
    // Dos asientos solo en el lado izquierdo (para simular espacio del chofer)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSeat(seat1, isWindowSeat: true),
          _buildSeat(seat2),
          const SizedBox(width: 136), // Espacio para el lado derecho vacío
        ],
      ),
    );
  }

  Widget _buildLastRow35() {
    // Última fila para 35 asientos: 29, 30, 31 (centro), 32, 33
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(29, isWindowSeat: true),
        _buildSeat(30),
        _buildSeat(31), // Asiento 31 en el medio
        _buildSeat(32),
        _buildSeat(33, isWindowSeat: true),
      ],
    );
  }

  Widget _buildLastRow41() {
    // Última fila para 41 asientos: 37, 38, 41 (centro), 39, 40
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSeat(37, isWindowSeat: true),
        _buildSeat(38),
        _buildSeat(41), // Asiento 41 en el medio
        _buildSeat(39),
        _buildSeat(40, isWindowSeat: true),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Hacer el mapa dinámico según el tamaño disponible
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        return Container(
          width: availableWidth,
          height: availableHeight,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Selector de capacidad (compacto en la parte superior)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
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
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
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
                const SizedBox(height: 12),

                // Mapa de asientos (sin título ni leyenda)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildSeatRows(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
