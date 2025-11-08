import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/caja_database.dart';
import 'detalle_cierre_screen.dart';

/// Pantalla de historial de cierres de caja
class HistorialCierresScreen extends StatefulWidget {
  @override
  _HistorialCierresScreenState createState() => _HistorialCierresScreenState();
}

class _HistorialCierresScreenState extends State<HistorialCierresScreen> {
  final CajaDatabase _cajaDatabase = CajaDatabase();
  List<Map<String, dynamic>> _cierresCaja = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cierres = await _cajaDatabase.getCierresCaja();

      // Ordenar por fecha (más reciente primero)
      cierres.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      setState(() {
        _cierresCaja = cierres;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar historial: $e')),
      );
    }
  }

  Future<void> _verDetalleCierre(Map<String, dynamic> cierre) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleCierreScreen(cierre: cierre),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Cierres'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _cierresCaja.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 70,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'No hay cierres de caja registrados',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _cierresCaja.length,
        padding: EdgeInsets.all(16.0),
        itemBuilder: (context, index) {
          final cierre = _cierresCaja[index];
          final fecha = cierre['fecha'];
          final hora = cierre['hora'];
          final total = cierre['total'];
          final cantidad = cierre['cantidad'];

          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Icon(Icons.receipt_long, color: Colors.green.shade700),
              ),
              title: Text(
                'Cierre: $fecha',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                  'Hora: $hora - Total: \$${NumberFormat('#,###').format(total)} - Ventas: $cantidad'
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _verDetalleCierre(cierre),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        },
      ),
    );
  }
}
