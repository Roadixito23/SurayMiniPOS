import 'package:flutter/material.dart';

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
    if (metodoPago != 'Personalizar') return;

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

    if (metodoPago == 'Personalizar' && efectivo + tarjeta != widget.totalAmount) {
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
      title: Text('Método de Pago'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total: \$${widget.totalAmount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            RadioListTile<String>(
              title: Text('Efectivo'),
              value: 'Efectivo',
              groupValue: metodoPago,
              onChanged: _onMetodoChanged,
            ),
            RadioListTile<String>(
              title: Text('Tarjeta'),
              value: 'Tarjeta',
              groupValue: metodoPago,
              onChanged: _onMetodoChanged,
            ),
            RadioListTile<String>(
              title: Text('Personalizar'),
              value: 'Personalizar',
              groupValue: metodoPago,
              onChanged: _onMetodoChanged,
            ),
            if (metodoPago == 'Personalizar') ...[
              SizedBox(height: 16),
              TextField(
                controller: _efectivoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Efectivo',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _tarjetaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Tarjeta',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
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
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: errorMessage == null ? _confirmar : null,
          child: Text('Confirmar'),
        ),
      ],
    );
  }
}
