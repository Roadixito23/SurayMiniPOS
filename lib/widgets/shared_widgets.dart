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
