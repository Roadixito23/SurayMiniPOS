import 'package:flutter/material.dart';
import 'comprobante.dart';
import 'shared_widgets.dart';

class AdminComprobantesScreen extends StatefulWidget {
  @override
  _AdminComprobantesScreenState createState() => _AdminComprobantesScreenState();
}

class _AdminComprobantesScreenState extends State<AdminComprobantesScreen> {
  final ComprobanteManager _comprobanteManager = ComprobanteManager();

  // Estado para el contador actual
  int _counter = 0;
  String _formattedCounter = '000000';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounter();
  }

  // Cargar el contador del almacenamiento local
  Future<void> _loadCounter() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _comprobanteManager.initialize();

      final counter = await _comprobanteManager.getCurrentCounter();
      final formattedCounter = await _comprobanteManager.getCurrentFormattedCounter();

      setState(() {
        _counter = counter;
        _formattedCounter = formattedCounter;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al cargar datos: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // Reiniciar contador
  Future<void> _resetCounter() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: 'Confirmar Reinicio',
        content: 'Esta acción reiniciará el contador de comprobantes a 000001. ¿Desea continuar?',
      ),
    );

    if (confirmar == true) {
      try {
        await _comprobanteManager.resetCounter();

        // Refrescar el contador
        await _loadCounter();

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Contador reiniciado correctamente'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al reiniciar contador: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Administración de Comprobantes'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información general
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información de Comprobantes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 16),
                    _infoRow('Contador actual:', _counter.toString()),
                    _infoRow('Próximo comprobante:', _formattedCounter),
                    _infoRow('Formato de tickets:', _formattedCounter),
                    SizedBox(height: 8),
                    Divider(),
                    SizedBox(height: 8),
                    Text(
                      'El sistema usa un único contador secuencial de 6 dígitos (000001-999999) para todos los comprobantes.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Sección de reinicio
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reinicio de Contador',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Reinicia el contador a 000001. El próximo comprobante (tanto de boletos como de carga) comenzará desde este número.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '⚠️ Advertencia: Esta acción no se puede deshacer.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _resetCounter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('REINICIAR CONTADOR A 000001'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Información adicional
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información del Sistema',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• El contador se reinicia automáticamente a 000001 después de llegar a 999999.\n'
                          '• Todos los comprobantes comparten el mismo contador secuencial.\n'
                          '• Todos los tickets (bus y carga) usan exactamente el mismo formato de numeración.\n'
                          '• El contador se guarda localmente y persiste al reiniciar la aplicación.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construye una fila de información
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}