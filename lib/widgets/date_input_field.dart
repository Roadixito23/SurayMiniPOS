import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'numeric_keyboard.dart';

class DateInputField extends StatefulWidget {
  final String? value;
  final Function(String) onChanged;
  final String? Function(String)? validator;
  final VoidCallback? onEnterPressed;
  final FocusNode? focusNode;

  const DateInputField({
    Key? key,
    this.value,
    required this.onChanged,
    this.validator,
    this.onEnterPressed,
    this.focusNode,
  }) : super(key: key);

  @override
  _DateInputFieldState createState() => _DateInputFieldState();
}

class _DateInputFieldState extends State<DateInputField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String? _errorText;
  String _rawInput = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);

    if (widget.value != null) {
      _rawInput = widget.value!.replaceAll('/', '');
    }

    if (widget.validator != null && widget.value != null) {
      _errorText = widget.validator!(widget.value!);
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      setState(() {});
      // Posicionar cursor al final cuando gana foco
      Future.microtask(() {
        if (_controller.text.isNotEmpty) {
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(DateInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != null) {
      _rawInput = widget.value!.replaceAll('/', '');
      _controller.text = _formatDate(_rawInput);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.removeListener(_handleFocusChange);
      _focusNode.dispose();
    }
    super.dispose();
  }

  String _formatDate(String raw) {
    // Formato: 050825 -> 05/08/25
    if (raw.isEmpty) return '';

    String formatted = '';
    for (int i = 0; i < raw.length && i < 6; i++) {
      formatted += raw[i];
      if (i == 1 || i == 3) {
        formatted += '/';
      }
    }
    return formatted;
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
    // Solo aceptar números
    if (int.tryParse(key) == null) return;

    // Máximo 6 dígitos (ddmmaa)
    if (_rawInput.length >= 6) return;

    _rawInput += key;
    String formatted = _formatDate(_rawInput);

    _controller.text = formatted;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: formatted.length),
    );
    _handleValueChanged(formatted);
  }

  void _handleDelete() {
    if (_rawInput.isNotEmpty) {
      _rawInput = _rawInput.substring(0, _rawInput.length - 1);
      String formatted = _formatDate(_rawInput);
      _controller.text = formatted;
      _handleValueChanged(formatted);
    }
  }

  void _handleClear() {
    _rawInput = '';
    _controller.text = '';
    _handleValueChanged('');
  }

  void _handleClearEntry() {
    _rawInput = '';
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
        // Campo de entrada
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _errorText != null ? Colors.red : Colors.grey.shade400,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'DD/MM/AA',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

        // Teclado numérico
        Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Card(
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: NumericKeyboard(
                onKeyPressed: _handleKeyPressed,
                onDelete: _handleDelete,
                onClear: _handleClear,
                onClearEntry: _handleClearEntry,
                onEnter: _handleEnter,
                buttonColor: Colors.grey.shade200,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
