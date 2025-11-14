import 'package:flutter/material.dart';

/// Clase helper para obtener los colores según el tipo de día
class DayThemeHelper {
  static Map<String, Color> getThemeColors(String tipoDia) {
    bool isDomingoFeriado = tipoDia.toUpperCase().contains('DOMINGO') ||
                           tipoDia.toUpperCase().contains('FERIADO');

    if (isDomingoFeriado) {
      return {
        'primary': Colors.orange.shade700,
        'secondary': Colors.orange.shade100,
        'accent': Colors.deepOrange.shade800,
        'gradient1': Colors.orange.shade50,
        'gradient2': Colors.deepOrange.shade100,
      };
    } else {
      return {
        'primary': Colors.blue.shade700,
        'secondary': Colors.blue.shade100,
        'accent': Colors.blue.shade900,
        'gradient1': Colors.blue.shade50,
        'gradient2': Colors.lightBlue.shade100,
      };
    }
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        backgroundColor: Colors.blue,
      ),
      child: Text(label),
    );
  }
}

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;

  const ConfirmationDialog({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Confirmar')),
      ],
    );
  }
}

/// Widget para seleccionar el método de pago
/// Retorna un Map con: {'metodo': String, 'montoEfectivo': double?, 'montoTarjeta': double?}
class PaymentMethodDialog extends StatefulWidget {
  final double totalAmount;
  final double? efectivoDisponible;

  const PaymentMethodDialog({
    required this.totalAmount,
    this.efectivoDisponible,
  });

  @override
  _PaymentMethodDialogState createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<PaymentMethodDialog> {
  String metodoPago = 'Efectivo';
  final TextEditingController _efectivoController = TextEditingController();
  final TextEditingController _tarjetaController = TextEditingController();
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _efectivoController.text = widget.totalAmount.toStringAsFixed(0);
    _tarjetaController.text = '0';

    _efectivoController.addListener(_onAmountChanged);
    _tarjetaController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (metodoPago != 'Pago Mixto') return;

    double efectivo = double.tryParse(_efectivoController.text) ?? 0;
    double tarjeta = double.tryParse(_tarjetaController.text) ?? 0;

    if (efectivo + tarjeta != widget.totalAmount) {
      setState(() {
        errorMessage = 'La suma debe ser igual al total: \$${widget.totalAmount.toStringAsFixed(0)}';
      });
    } else {
      setState(() {
        errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _efectivoController.dispose();
    _tarjetaController.dispose();
    super.dispose();
  }

  void _onMetodoChanged(String? value) {
    if (value == null) return;

    setState(() {
      metodoPago = value;
      errorMessage = null;

      if (metodoPago == 'Efectivo') {
        _efectivoController.text = widget.totalAmount.toStringAsFixed(0);
        _tarjetaController.text = '0';
      } else if (metodoPago == 'Tarjeta') {
        _efectivoController.text = '0';
        _tarjetaController.text = widget.totalAmount.toStringAsFixed(0);
      }
    });
  }

  void _confirmar() {
    double efectivo = double.tryParse(_efectivoController.text) ?? 0;
    double tarjeta = double.tryParse(_tarjetaController.text) ?? 0;

    if (metodoPago == 'Pago Mixto' && efectivo + tarjeta != widget.totalAmount) {
      setState(() {
        errorMessage = 'La suma debe ser igual al total';
      });
      return;
    }

    // Validar si hay efectivo disponible suficiente (solo para gastos)
    if (widget.efectivoDisponible != null && efectivo > widget.efectivoDisponible!) {
      // Mostrar advertencia pero permitir continuar
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Advertencia'),
          content: Text(
            'El monto en efectivo (\$${efectivo.toStringAsFixed(0)}) supera el disponible (\$${widget.efectivoDisponible!.toStringAsFixed(0)}). ¿Desea continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar advertencia
                Navigator.pop(context, {
                  'metodo': metodoPago,
                  'montoEfectivo': efectivo,
                  'montoTarjeta': tarjeta,
                }); // Cerrar diálogo principal
              },
              child: Text('Continuar'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'metodo': metodoPago,
      'montoEfectivo': efectivo,
      'montoTarjeta': tarjeta,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.payment, color: Colors.blue.shade700, size: 28),
          SizedBox(width: 12),
          Text(
            'MÉTODO DE PAGO',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total a pagar:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '\$${widget.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Efectivo - Color turquesa
            Container(
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: metodoPago == 'Efectivo' ? Colors.teal.shade400 : Colors.grey.shade300,
                  width: 2,
                ),
                color: metodoPago == 'Efectivo' ? Colors.teal.shade50 : Colors.white,
              ),
              child: RadioListTile<String>(
                title: Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.teal.shade600, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Efectivo',
                      style: TextStyle(
                        fontWeight: metodoPago == 'Efectivo' ? FontWeight.bold : FontWeight.normal,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
                value: 'Efectivo',
                groupValue: metodoPago,
                onChanged: _onMetodoChanged,
                activeColor: Colors.teal.shade600,
              ),
            ),

            // Tarjeta - Color púrpura
            Container(
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: metodoPago == 'Tarjeta' ? Colors.purple.shade400 : Colors.grey.shade300,
                  width: 2,
                ),
                color: metodoPago == 'Tarjeta' ? Colors.purple.shade50 : Colors.white,
              ),
              child: RadioListTile<String>(
                title: Row(
                  children: [
                    Icon(Icons.credit_card, color: Colors.purple.shade600, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Tarjeta',
                      style: TextStyle(
                        fontWeight: metodoPago == 'Tarjeta' ? FontWeight.bold : FontWeight.normal,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                value: 'Tarjeta',
                groupValue: metodoPago,
                onChanged: _onMetodoChanged,
                activeColor: Colors.purple.shade600,
              ),
            ),

            // Pago Mixto
            Container(
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: metodoPago == 'Pago Mixto' ? Colors.orange.shade400 : Colors.grey.shade300,
                  width: 2,
                ),
                color: metodoPago == 'Pago Mixto' ? Colors.orange.shade50 : Colors.white,
              ),
              child: RadioListTile<String>(
                title: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.orange.shade600, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Pago Mixto',
                      style: TextStyle(
                        fontWeight: metodoPago == 'Pago Mixto' ? FontWeight.bold : FontWeight.normal,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                value: 'Pago Mixto',
                groupValue: metodoPago,
                onChanged: _onMetodoChanged,
                activeColor: Colors.orange.shade600,
              ),
            ),

            if (metodoPago == 'Pago Mixto') ...[
              SizedBox(height: 16),
              TextField(
                controller: _efectivoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Efectivo',
                  prefixIcon: Icon(Icons.attach_money, color: Colors.teal.shade600),
                  prefixText: '\$',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _tarjetaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Tarjeta',
                  prefixIcon: Icon(Icons.credit_card, color: Colors.purple.shade600),
                  prefixText: '\$',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: errorMessage == null ? _confirmar : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('CONFIRMAR'),
        ),
      ],
    );
  }
}

/// Widget para registrar gastos
/// Retorna un Map con: {'tipoGasto': String, 'monto': double, 'numeroMaquina': String?, 'chofer': String?, 'descripcion': String?}
class ExpenseDialog extends StatefulWidget {
  final double? efectivoDisponible;

  const ExpenseDialog({this.efectivoDisponible});

  @override
  _ExpenseDialogState createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  String tipoGasto = 'Combustible';
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _numeroMaquinaController = TextEditingController();
  final TextEditingController _choferController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  String? errorMessage;

  @override
  void dispose() {
    _montoController.dispose();
    _numeroMaquinaController.dispose();
    _choferController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _confirmar() {
    double monto = double.tryParse(_montoController.text) ?? 0;

    if (monto <= 0) {
      setState(() {
        errorMessage = 'Ingrese un monto válido';
      });
      return;
    }

    if (tipoGasto == 'Combustible') {
      if (_numeroMaquinaController.text.trim().isEmpty) {
        setState(() {
          errorMessage = 'Ingrese el N° de máquina';
        });
        return;
      }

      if (_numeroMaquinaController.text.length > 6) {
        setState(() {
          errorMessage = 'N° de máquina máximo 6 caracteres';
        });
        return;
      }

      if (_choferController.text.trim().isEmpty) {
        setState(() {
          errorMessage = 'Ingrese el nombre del chofer';
        });
        return;
      }
    } else {
      if (_descripcionController.text.trim().isEmpty) {
        setState(() {
          errorMessage = 'Ingrese una descripción';
        });
        return;
      }
    }

    // Validar efectivo disponible
    if (widget.efectivoDisponible != null && monto > widget.efectivoDisponible!) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Advertencia'),
          content: Text(
            'El gasto (\$${monto.toStringAsFixed(0)}) supera el efectivo disponible (\$${widget.efectivoDisponible!.toStringAsFixed(0)}). ¿Desea continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar advertencia
                _returnResult(monto); // Retornar resultado
              },
              child: Text('Continuar'),
            ),
          ],
        ),
      );
      return;
    }

    _returnResult(monto);
  }

  void _returnResult(double monto) {
    Navigator.pop(context, {
      'tipoGasto': tipoGasto,
      'monto': monto,
      'numeroMaquina': tipoGasto == 'Combustible' ? _numeroMaquinaController.text.trim() : null,
      'chofer': tipoGasto == 'Combustible' ? _choferController.text.trim() : null,
      'descripcion': tipoGasto == 'Otros' ? _descripcionController.text.trim() : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Registrar Gasto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.efectivoDisponible != null)
              Text(
                'Efectivo disponible: \$${widget.efectivoDisponible!.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            SizedBox(height: 16),
            RadioListTile<String>(
              title: Text('Combustible'),
              value: 'Combustible',
              groupValue: tipoGasto,
              onChanged: (value) => setState(() => tipoGasto = value!),
            ),
            RadioListTile<String>(
              title: Text('Otros'),
              value: 'Otros',
              groupValue: tipoGasto,
              onChanged: (value) => setState(() => tipoGasto = value!),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto en efectivo',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
            ),
            if (tipoGasto == 'Combustible') ...[
              SizedBox(height: 12),
              TextField(
                controller: _numeroMaquinaController,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'N° de Máquina (máx 6 caracteres)',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _choferController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Chofer',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (tipoGasto == 'Otros') ...[
              SizedBox(height: 12),
              TextField(
                controller: _descripcionController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (errorMessage != null) ...[
              SizedBox(height: 8),
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          child: Text('Registrar'),
        ),
      ],
    );
  }
}

/// Widget para confirmar venta con animación y colores según tipo de día
class AnimatedConfirmDialog extends StatefulWidget {
  final String tipoDia;
  final String tarifa;
  final String destino;
  final String? origen;
  final String horario;
  final String asiento;
  final String valor;
  final String? kilometro;

  const AnimatedConfirmDialog({
    required this.tipoDia,
    required this.tarifa,
    required this.destino,
    required this.horario,
    required this.asiento,
    required this.valor,
    this.origen,
    this.kilometro,
  });

  @override
  _AnimatedConfirmDialogState createState() => _AnimatedConfirmDialogState();
}

class _AnimatedConfirmDialogState extends State<AnimatedConfirmDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onClose(bool result) {
    _controller.reverse().then((_) => Navigator.pop(context, result));
  }

  @override
  Widget build(BuildContext context) {
    final colors = DayThemeHelper.getThemeColors(widget.tipoDia);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors['gradient1']!, colors['gradient2']!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.confirmation_number, color: colors['primary'], size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirmar Venta',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors['accent'],
                        ),
                      ),
                      Text(
                        widget.tipoDia,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors['primary'],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoCard('Tarifa', widget.tarifa, colors),
                SizedBox(height: 8),
                if (widget.destino == 'Intermedio' && widget.origen != null)
                  _buildInfoCard('Origen', widget.origen!, colors),
                _buildInfoCard(
                  'Destino',
                  widget.destino == 'Intermedio' ? '${widget.destino} (Km ${widget.kilometro ?? "?"})' : widget.destino,
                  colors,
                ),
                SizedBox(height: 8),
                _buildInfoCard('Salida', widget.horario, colors),
                SizedBox(height: 8),
                _buildInfoCard('Asiento', widget.asiento, colors),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors['secondary'],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors['primary']!, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'VALOR TOTAL:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors['accent'],
                        ),
                      ),
                      Text(
                        '\$${widget.valor}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colors['primary'],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _onClose(false),
              child: Text('CANCELAR', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton.icon(
              onPressed: () => _onClose(true),
              icon: Icon(Icons.check_circle),
              label: Text('CONFIRMAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['primary'],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, Map<String, Color> colors) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors['gradient1'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors['secondary']!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: colors['accent'],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget para seleccionar método de pago con animación y colores según tipo de día
class AnimatedPaymentMethodDialog extends StatefulWidget {
  final double totalAmount;
  final double? efectivoDisponible;
  final String tipoDia;

  const AnimatedPaymentMethodDialog({
    required this.totalAmount,
    required this.tipoDia,
    this.efectivoDisponible,
  });

  @override
  _AnimatedPaymentMethodDialogState createState() => _AnimatedPaymentMethodDialogState();
}

class _AnimatedPaymentMethodDialogState extends State<AnimatedPaymentMethodDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  String metodoPago = 'Efectivo';
  final TextEditingController _efectivoController = TextEditingController();
  final TextEditingController _tarjetaController = TextEditingController();
  String? errorMessage;
  double montoFaltante = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();

    _efectivoController.text = widget.totalAmount.toStringAsFixed(0);
    _tarjetaController.text = '0';

    _efectivoController.addListener(_onAmountChanged);
    _tarjetaController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (metodoPago != 'Pago Mixto') return;

    double efectivo = double.tryParse(_efectivoController.text) ?? 0;
    double tarjeta = double.tryParse(_tarjetaController.text) ?? 0;
    double total = efectivo + tarjeta;

    setState(() {
      montoFaltante = widget.totalAmount - total;

      if (montoFaltante.abs() < 0.01) {
        errorMessage = null;
        montoFaltante = 0.0;
      } else if (montoFaltante > 0) {
        errorMessage = 'Falta: \$${montoFaltante.toStringAsFixed(0)}';
      } else {
        errorMessage = 'Exceso: \$${(-montoFaltante).toStringAsFixed(0)}';
      }
    });
  }

  @override
  void dispose() {
    _efectivoController.dispose();
    _tarjetaController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onMetodoChanged(String? value) {
    if (value == null) return;

    setState(() {
      metodoPago = value;
      errorMessage = null;
      montoFaltante = 0.0;

      if (metodoPago == 'Efectivo') {
        _efectivoController.text = widget.totalAmount.toStringAsFixed(0);
        _tarjetaController.text = '0';
      } else if (metodoPago == 'Tarjeta') {
        _efectivoController.text = '0';
        _tarjetaController.text = widget.totalAmount.toStringAsFixed(0);
      }
    });
  }

  void _confirmar() {
    double efectivo = double.tryParse(_efectivoController.text) ?? 0;
    double tarjeta = double.tryParse(_tarjetaController.text) ?? 0;

    if (metodoPago == 'Pago Mixto' && (efectivo + tarjeta).abs() > 0.01 && (efectivo + tarjeta - widget.totalAmount).abs() > 0.01) {
      setState(() {
        errorMessage = 'La suma debe ser igual al total';
      });
      return;
    }

    // Validar si hay efectivo disponible suficiente (solo para gastos)
    if (widget.efectivoDisponible != null && efectivo > widget.efectivoDisponible!) {
      // Mostrar advertencia pero permitir continuar
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Advertencia'),
          content: Text(
            'El monto en efectivo (\$${efectivo.toStringAsFixed(0)}) supera el disponible (\$${widget.efectivoDisponible!.toStringAsFixed(0)}). ¿Desea continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar advertencia
                _onClose({
                  'metodo': metodoPago,
                  'montoEfectivo': efectivo,
                  'montoTarjeta': tarjeta,
                }); // Cerrar diálogo principal
              },
              child: Text('Continuar'),
            ),
          ],
        ),
      );
      return;
    }

    _onClose({
      'metodo': metodoPago,
      'montoEfectivo': efectivo,
      'montoTarjeta': tarjeta,
    });
  }

  void _onClose(dynamic result) {
    _controller.reverse().then((_) => Navigator.pop(context, result));
  }

  @override
  Widget build(BuildContext context) {
    final colors = DayThemeHelper.getThemeColors(widget.tipoDia);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors['gradient1']!, colors['gradient2']!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.payment, color: colors['primary'], size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Método de Pago',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors['accent'],
                        ),
                      ),
                      Text(
                        'Total: \$${widget.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors['primary'],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPaymentOption('Efectivo', colors),
                _buildPaymentOption('Tarjeta', colors),
                _buildPaymentOption('Pago Mixto', colors),
                if (metodoPago == 'Pago Mixto') ...[
                  SizedBox(height: 16),
                  TextField(
                    controller: _efectivoController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Efectivo',
                      prefixText: '\$',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors['primary']!, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _tarjetaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Tarjeta',
                      prefixText: '\$',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors['primary']!, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Mostrar dinero faltante en tiempo real
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: montoFaltante == 0 ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: montoFaltante == 0 ? Colors.green : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              montoFaltante == 0 ? Icons.check_circle : Icons.info,
                              color: montoFaltante == 0 ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              montoFaltante == 0 ? 'Completo' : (montoFaltante > 0 ? 'Falta' : 'Exceso'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: montoFaltante == 0 ? Colors.green.shade700 : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        if (montoFaltante != 0)
                          Text(
                            '\$${montoFaltante.abs().toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (errorMessage != null) ...[
                    SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _onClose(null),
              child: Text('CANCELAR', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: errorMessage == null && montoFaltante == 0 ? _confirmar : null,
              child: Text('CONFIRMAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['primary'],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String option, Map<String, Color> colors) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: metodoPago == option ? colors['secondary'] : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: metodoPago == option ? colors['primary']! : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: RadioListTile<String>(
        title: Text(
          option,
          style: TextStyle(
            fontWeight: metodoPago == option ? FontWeight.bold : FontWeight.normal,
            color: metodoPago == option ? colors['accent'] : Colors.grey.shade800,
          ),
        ),
        value: option,
        groupValue: metodoPago,
        onChanged: _onMetodoChanged,
        activeColor: colors['primary'],
      ),
    );
  }
}
