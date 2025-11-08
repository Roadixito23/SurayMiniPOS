import 'package:flutter/material.dart';

class NumericKeyboard extends StatelessWidget {
  final Function(String) onKeyPressed;
  final Function() onDelete;
  final Function() onClear;
  final Function() onClearEntry;
  final Function() onEnter;
  final bool enableDecimal;
  final Color buttonColor;
  final Color textColor;

  const NumericKeyboard({
    Key? key,
    required this.onKeyPressed,
    required this.onDelete,
    required this.onClear,
    required this.onClearEntry,
    required this.onEnter,
    this.enableDecimal = false,
    this.buttonColor = Colors.white,
    this.textColor = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280, // Reduje la altura al quitar el botón de borrar
      child: Column(
        children: [
          _buildKeyboardRow(['1', '2', '3']),
          _buildKeyboardRow(['4', '5', '6']),
          _buildKeyboardRow(['7', '8', '9']),
          _buildKeyboardRow([
            'clear-entry',
            '0',
            'delete',
          ]),
          SizedBox(height: 10),
          _buildEnterButton(),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> keys) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: keys.map((key) {
          if (key == 'delete') {
            return _buildDeleteButton();
          } else if (key == 'clear-entry') {
            return _buildClearEntryButton();
          } else if (key.isEmpty) {
            return Expanded(child: SizedBox());
          } else {
            return _buildNumberButton(key);
          }
        }).toList(),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: () => onKeyPressed(number),
          child: Text(
            number,
            style: TextStyle(fontSize: 24, color: textColor),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: onDelete,
          child: Icon(Icons.backspace, color: textColor),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearEntryButton() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: onClearEntry,
          child: Icon(Icons.clear, color: Colors.red.shade700),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnterButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: onEnter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ENTER',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              SizedBox(width: 8),
              Icon(Icons.keyboard_return, color: Colors.white),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}