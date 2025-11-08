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
