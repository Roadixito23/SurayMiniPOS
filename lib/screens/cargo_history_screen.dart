import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/cargo_database.dart';
import '../services/cargo_ticket_generator.dart';
import '../widgets/cargo_stats_widget.dart';

class CargoHistoryScreen extends StatefulWidget {
  @override
  _CargoHistoryScreenState createState() => _CargoHistoryScreenState();
}

class _CargoHistoryScreenState extends State<CargoHistoryScreen> {
  List<Map<String, dynamic>> _cargoReceipts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedDestination;
  List<String> _destinations = [];
  bool _isInTabView = false; // Para saber si está en la vista de tabs
  bool _showStats = true; // Mostrar estadísticas por defecto

  @override
  void initState() {
    super.initState();
    // Verificamos si la pantalla se está mostrando desde la navegación principal o no
    Future.delayed(Duration.zero, () {
      setState(() {
        _isInTabView = ModalRoute.of(context)?.settings.name != '/cargo_history';
      });
    });
    _loadCargoReceipts();
    _loadDestinations();
  }

  Future<void> _loadCargoReceipts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> receipts;

      if (_selectedDestination != null) {
        receipts = await CargoDatabase.getReceiptsByDestination(_selectedDestination!);
      } else if (_searchQuery.isNotEmpty) {
        receipts = await CargoDatabase.searchReceipts(_searchQuery);
      } else {
        receipts = await CargoDatabase.getCargoReceipts();
      }

      setState(() {
        _cargoReceipts = receipts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading cargo receipts: $e');
      setState(() {
        _cargoReceipts = [];
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando el historial: $e'))
      );
    }
  }

  Future<void> _loadDestinations() async {
    try {
      final destinations = await CargoDatabase.getUniqueDestinations();
      setState(() {
        _destinations = destinations;
      });
    } catch (e) {
      print('Error loading destinations: $e');
    }
  }

  // Agrupar recibos por transacción (comprobante)
  Map<String, List<Map<String, dynamic>>> get _groupedReceipts {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var receipt in _cargoReceipts) {
      final comprobante = receipt['comprobante'] as String;
      if (!grouped.containsKey(comprobante)) {
        grouped[comprobante] = [];
      }
      grouped[comprobante]!.add(receipt);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedReceipts = _groupedReceipts;

    return Scaffold(
      appBar: _isInTabView
          ? null // No mostrar AppBar si estamos en la vista de tabs (ya hay uno en HomeScreen)
          : AppBar(
        title: Text('Historial de Cargos'),
        backgroundColor: Colors.orange,
        actions: [
          // Toggle para mostrar/ocultar estadísticas
          IconButton(
            icon: Icon(_showStats ? Icons.analytics_outlined : Icons.analytics),
            onPressed: () {
              setState(() {
                _showStats = !_showStats;
              });
            },
            tooltip: _showStats ? 'Ocultar estadísticas' : 'Mostrar estadísticas',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCargoReceipts,
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Mostrar estadísticas si la opción está activada
          if (_showStats)
            CargoStatsWidget(
              cargoReceipts: _cargoReceipts,
              isLoading: _isLoading,
            ),

          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Buscar por destinatario, remitente, artículo...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty ?
                    IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _loadCargoReceipts();
                      },
                    ) : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    if (value.length > 2 || value.isEmpty) {
                      _loadCargoReceipts();
                    }
                  },
                ),

                // Filtro de destino
                if (_destinations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: DropdownButtonFormField<String?>(
                      decoration: InputDecoration(
                        labelText: 'Filtrar por destino',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      value: _selectedDestination,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos los destinos'),
                        ),
                        ..._destinations.map((dest) => DropdownMenuItem<String?>(
                          value: dest,
                          child: Text(dest),
                        )).toList(),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          _selectedDestination = value;
                        });
                        _loadCargoReceipts();
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Encabezado mostrando el número de resultados
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'Cargos encontrados: ${groupedReceipts.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),

          // Lista de recibos
          Expanded(
            child: _isLoading && _cargoReceipts.isEmpty
                ? Center(child: CircularProgressIndicator())
                : groupedReceipts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 70,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No se encontraron recibos de cargo',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedDestination != null)
                    TextButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text('Mostrar todos'),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _selectedDestination = null;
                        });
                        _loadCargoReceipts();
                      },
                    ),
                  // Añadir un botón para agregar un nuevo cargo cuando no hay datos
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Crear nuevo cargo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/venta_cargo'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: groupedReceipts.length,
              itemBuilder: (context, index) {
                final comprobante = groupedReceipts.keys.elementAt(index);
                final receipts = groupedReceipts[comprobante]!;
                final firstReceipt = receipts[0];

                // Buscar copias de cliente e inspector
                final clientCopy = receipts.firstWhere(
                      (r) => r['tipo'] == 'Cliente',
                  orElse: () => receipts[0],
                );

                final inspectorCopy = receipts.firstWhere(
                      (r) => r['tipo'] == 'Inspector',
                  orElse: () => receipts[0],
                );

                final date = DateTime.fromMillisecondsSinceEpoch(
                    firstReceipt['timestamp'] as int
                );
                final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ExpansionTile(
                    title: Text(
                      'Cargo: ${firstReceipt['destinatario']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Comprobante: $comprobante'),
                        Text('Fecha: $formattedDate'),
                      ],
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange[100],
                      child: Icon(Icons.inventory, color: Colors.orange),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detalles del Cargo:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8.0),
                            _buildDetailRow('Destinatario', '${firstReceipt['destinatario']}'),
                            _buildDetailRow('Remitente', '${firstReceipt['remitente']}'),
                            _buildDetailRow('Artículo', '${firstReceipt['articulo']}'),
                            _buildDetailRow('Destino', '${firstReceipt['destino'] ?? 'No especificado'}'),
                            _buildDetailRow('Precio', '\$${NumberFormat('#,###', 'es_CL').format(firstReceipt['precio'])}'),
                            SizedBox(height: 16.0),

                            Text(
                              'Opciones de reimpresión:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8.0),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildReprintButton(
                                  'Cliente',
                                  Colors.blue,
                                  Icons.person,
                                      () => _reprintCargoPdf(comprobante, clientCopy, 'Cliente'),
                                ),
                                _buildReprintButton(
                                  'Inspector',
                                  Colors.green,
                                  Icons.local_shipping,
                                      () => _reprintCargoPdf(comprobante, inspectorCopy, 'Inspector'),
                                ),
                                _buildReprintButton(
                                  'Ambas',
                                  Colors.orange,
                                  Icons.print,
                                      () {
                                    _reprintCargoPdf(comprobante, clientCopy, 'Cliente');
                                    _reprintCargoPdf(comprobante, inspectorCopy, 'Inspector');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/venta_cargo'),
        backgroundColor: Colors.orange,
        child: Icon(Icons.add),
        tooltip: 'Nuevo cargo',
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildReprintButton(String label, Color color, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),
      onPressed: onPressed,
    );
  }

  Future<void> _reprintCargoPdf(String comprobante, Map<String, dynamic> data, String tipo) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Reimprimir el ticket utilizando el nuevo generador
      await CargoTicketGenerator.reprintTicket(
        tipo: tipo,
        comprobante: comprobante,
        data: data,
      );

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reimpresión de $tipo completada'))
      );
    } catch (e) {
      print('Error al reimprimir: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reimprimir: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}