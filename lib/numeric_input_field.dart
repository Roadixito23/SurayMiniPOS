import 'package:flutter/material.dart';
import 'numeric_keyboard.dart';

class NumericInputField extends StatefulWidget {
  final String label;  // Mantenemos el parámetro label por compatibilidad
  final String? value;
  final Function(String) onChanged;
  final bool enableDecimal;
  final String prefix;
  final String suffix;
  final String? Function(String)? validator;
  final String hintText;
  final VoidCallback? onEnterPressed;
  final FocusNode? focusNode;

  const NumericInputField({
    Key? key,
    this.label = '',  // Ahora el label puede ser opcional
    this.value,
    required this.onChanged,
    this.enableDecimal = false,
    this.prefix = '',
    this.suffix = '',
    this.validator,
    this.hintText = '',
    this.onEnterPressed,
    this.focusNode,
  }) : super(key: key);

  @override
  _NumericInputFieldState createState() => _NumericInputFieldState();
}

class _NumericInputFieldState extends State<NumericInputField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _focusNode = widget.focusNode ?? FocusNode();

    // Ya no necesitamos mostrar/ocultar el teclado basado en foco
    // pero mantenemos el listener por si necesitamos realizar otras acciones al recibir foco
    _focusNode.addListener(_handleFocusChange);

    if (widget.validator != null && widget.value != null) {
      _errorText = widget.validator!(widget.value!);
    }
  }

  void _handleFocusChange() {
    // El teclado ya está visible, pero podríamos hacer otras cosas cuando el campo recibe foco
    if (_focusNode.hasFocus) {
      setState(() {}); // Actualizamos el estado para reflejar el foco activo
    }
  }

  @override
  void didUpdateWidget(NumericInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) {
      // Solo eliminar el FocusNode si lo creamos internamente
      _focusNode.removeListener(_handleFocusChange);
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleValueChanged(String value) {
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(value);
      });
    }
    widget.onChanged(value);
  }

  void _handleKeyPressed(String key) {
    String currentText = _controller.text;
    String newValue = '';

    // Verificar si es un campo para horarios
    bool isTimeField = widget.label.toLowerCase().contains('horario') ||
        widget.hintText.toLowerCase().contains('hh:mm') ||
        widget.hintText.toLowerCase().contains('hora');

    // Lógica simplificada para insertar ":"
    if (isTimeField) {
      // Si ya tiene 2 dígitos y no tiene ":", agrega ":" automáticamente
      if (currentText.length == 2 && !currentText.contains(':')) {
        newValue = currentText + ':' + key;
      }
      // Si ya tiene 5 o más caracteres, no agregar más (formato HH:MM)
      else if (currentText.length >= 5) {
        return;
      }
      // En caso contrario, concatenar normalmente
      else {
        newValue = currentText + key;
      }
    } else {
      // Para otros campos, simplemente añadir el número
      newValue = currentText + key;
    }

    _controller.text = newValue;
    _handleValueChanged(newValue);
  }

  void _handleDelete() {
    if (_controller.text.isNotEmpty) {
      String newValue = _controller.text.substring(0, _controller.text.length - 1);
      _controller.text = newValue;
      _handleValueChanged(newValue);
    }
  }

  void _handleClear() {
    _controller.text = '';
    _handleValueChanged('');
  }

  void _handleClearEntry() {
    _controller.text = '';
    _handleValueChanged('');
  }

  void _handleEnter() {
    // Validar el valor actual
    if (widget.validator != null) {
      final error = widget.validator!(_controller.text);
      setState(() {
        _errorText = error;
      });

      // Si hay un error, no proceder con el Enter
      if (error != null) {
        return;
      }
    }
    if (widget.onEnterPressed != null) {
      widget.onEnterPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta del campo (solo si se proporciona)
        if (widget.label.isNotEmpty)
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        if (widget.label.isNotEmpty)
          SizedBox(height: 8),

        // Campo de entrada
        GestureDetector(
          onTap: () {
            // Ya no alternamos la visibilidad del teclado, solo damos foco
            _focusNode.requestFocus();
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _errorText != null ? Colors.red : Colors.grey.shade400,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                if (widget.prefix.isNotEmpty)
                  Text(
                    widget.prefix,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                Expanded(
                  child: Text(
                    _controller.text.isEmpty ? widget.hintText : _controller.text,
                    style: TextStyle(
                      fontSize: 18,
                      color: _controller.text.isEmpty ? Colors.grey : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (widget.suffix.isNotEmpty)
                  Text(
                    widget.suffix,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),

        // Mensaje de error
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 12.0),
            child: Text(
              _errorText!,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),

        // Teclado numérico (siempre visible)
        Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: NumericKeyboard(
                onKeyPressed: _handleKeyPressed,
                onDelete: _handleDelete,
                onClear: _handleClear,
                onClearEntry: _handleClearEntry,
                onEnter: _handleEnter,
                enableDecimal: widget.enableDecimal,
                buttonColor: Colors.grey.shade200,
              ),
            ),
          ),
        ),
      ],
    );
  }
}