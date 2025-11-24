import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../database/caja_database.dart';
import '../database/app_database.dart';
import '../models/tarifa.dart';
import '../widgets/pie_chart_widget.dart';

enum FiltroTemporal { hoy, semanal, mensual }
enum FiltroTipo { ambos, puntoAPunto, intermedio }
enum VistaEstadisticas { pasajeros, mixto, monetario }

class EstadisticasScreen extends StatefulWidget {
  @override
  _EstadisticasScreenState createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  bool _isLoading = true;
  FiltroTemporal _filtroTemporal = FiltroTemporal.hoy;
  FiltroTipo _filtroTipo = FiltroTipo.ambos;
  VistaEstadisticas _vistaActual = VistaEstadisticas.mixto;

  List<Map<String, dynamic>> _ventasFiltradas = [];
  Map<String, Map<String, dynamic>> _estadisticasPorHorario = {};
  Map<String, int> _pasajerosPorTipo = {};
  double _totalVentas = 0;
  int _totalPasajeros = 0;
  Map<String, Color> _coloresTarifas = {};

  @override
  void initState() {
    super.initState();
    _cargarColoresTarifas();
    _cargarEstadisticas();
  }

  Future<void> _cargarColoresTarifas() async {
    try {
      final tarifasData = await AppDatabase.instance.getAllTarifas();
      final tarifas = tarifasData.map((map) => Tarifa.fromMap(map)).toList();

      Map<String, Color> colores = {};
      for (var tarifa in tarifas) {
        if (tarifa.color != null && tarifa.color!.isNotEmpty) {
          try {
            colores[tarifa.categoria] = Color(int.parse(tarifa.color!, radix: 16));
          } catch (e) {
            colores[tarifa.categoria] = _getColorPorDefecto(tarifa.categoria);
          }
        } else {
          colores[tarifa.categoria] = _getColorPorDefecto(tarifa.categoria);
        }
      }

      setState(() {
        _coloresTarifas = colores;
      });
    } catch (e) {
      print('Error cargando colores de tarifas: $e');
    }
  }

  Color _getColorPorDefecto(String categoria) {
    if (categoria.toUpperCase().contains('GENERAL')) {
      return Colors.blue.shade400;
    } else if (categoria.toUpperCase().contains('ESCOLAR')) {
      return Colors.green.shade400;
    } else if (categoria.toUpperCase().contains('ADULTO')) {
      return Colors.purple.shade400;
    } else if (categoria.toUpperCase().contains('INTERMEDIO')) {
      return Colors.orange.shade400;
    }
    return Colors.grey.shade400;
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _isLoading = true);

    try {
      // Cargar todas las ventas desde el archivo JSON
      final directory = await getApplicationDocumentsDirectory();
      final ventasFile = File('${directory.path}/ventas_diarias.json');

      List<Map<String, dynamic>> todasLasVentas = [];

      if (await ventasFile.exists()) {
        String content = await ventasFile.readAsString();
        var decoded = json.decode(content);

        if (decoded is List) {
          todasLasVentas = decoded.map((v) => Map<String, dynamic>.from(v as Map)).toList();
        }
      }

      // Cargar también ventas de cierres de caja anteriores
      final cierresFile = File('${directory.path}/cierres_caja.json');
      if (await cierresFile.exists()) {
        String content = await cierresFile.readAsString();
        var decoded = json.decode(content);

        if (decoded is List) {
          for (var cierre in decoded) {
            if (cierre is Map && cierre.containsKey('ventas')) {
              List<dynamic> ventasCierre = cierre['ventas'] as List;
              todasLasVentas.addAll(
                ventasCierre.map((v) => Map<String, dynamic>.from(v as Map)).toList()
              );
            }
          }
        }
      }

      // Filtrar ventas por tipo (bus solamente)
      todasLasVentas = todasLasVentas.where((v) => v['tipo'] == 'bus').toList();

      // Aplicar filtros
      _ventasFiltradas = _aplicarFiltros(todasLasVentas);

      // Calcular estadísticas
      _calcularEstadisticas();

    } catch (e) {
      print('Error cargando estadísticas: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _aplicarFiltros(List<Map<String, dynamic>> ventas) {
    DateTime ahora = DateTime.now();
    DateTime fechaInicio;

    // Filtro temporal
    switch (_filtroTemporal) {
      case FiltroTemporal.hoy:
        fechaInicio = DateTime(ahora.year, ahora.month, ahora.day);
        break;
      case FiltroTemporal.semanal:
        fechaInicio = ahora.subtract(Duration(days: 7));
        break;
      case FiltroTemporal.mensual:
        fechaInicio = ahora.subtract(Duration(days: 30));
        break;
    }

    ventas = ventas.where((v) {
      try {
        DateTime fechaVenta = DateTime.parse(v['fecha']);
        return fechaVenta.isAfter(fechaInicio) || fechaVenta.isAtSameMomentAs(fechaInicio);
      } catch (e) {
        return false;
      }
    }).toList();

    // Filtro por tipo (Punto a Punto vs Intermedio)
    if (_filtroTipo != FiltroTipo.ambos) {
      ventas = ventas.where((v) {
        String destino = v['destino']?.toString() ?? '';
        bool esIntermedio = destino.contains('Intermedio');

        if (_filtroTipo == FiltroTipo.intermedio) {
          return esIntermedio;
        } else {
          return !esIntermedio;
        }
      }).toList();
    }

    return ventas;
  }

  void _calcularEstadisticas() {
    _estadisticasPorHorario = {};
    _pasajerosPorTipo = {};
    _totalVentas = 0;
    _totalPasajeros = _ventasFiltradas.length;

    for (var venta in _ventasFiltradas) {
      String horario = venta['horario']?.toString() ?? 'Sin horario';
      double valor = (venta['valor'] ?? 0).toDouble();
      String tipoBoleto = venta['tipoBoleto']?.toString() ?? 'PUBLICO GENERAL';

      _totalVentas += valor;

      // Estadísticas por horario
      if (!_estadisticasPorHorario.containsKey(horario)) {
        _estadisticasPorHorario[horario] = {
          'pasajeros': 0,
          'total': 0.0,
        };
      }
      _estadisticasPorHorario[horario]!['pasajeros'] =
        (_estadisticasPorHorario[horario]!['pasajeros'] as int) + 1;
      _estadisticasPorHorario[horario]!['total'] =
        (_estadisticasPorHorario[horario]!['total'] as double) + valor;

      // Conteo por tipo de boleto
      _pasajerosPorTipo[tipoBoleto] = (_pasajerosPorTipo[tipoBoleto] ?? 0) + 1;
    }

    setState(() {});
  }

  String _obtenerHorarioMayorDemanda() {
    if (_estadisticasPorHorario.isEmpty) return 'N/A';

    var entrada = _estadisticasPorHorario.entries.reduce((a, b) {
      int pasajerosA = a.value['pasajeros'] as int;
      int pasajerosB = b.value['pasajeros'] as int;
      return pasajerosA > pasajerosB ? a : b;
    });

    return '${entrada.key} (${entrada.value['pasajeros']} pasajeros)';
  }

  String _obtenerHorarioMenorDemanda() {
    if (_estadisticasPorHorario.isEmpty) return 'N/A';

    var entrada = _estadisticasPorHorario.entries.reduce((a, b) {
      int pasajerosA = a.value['pasajeros'] as int;
      int pasajerosB = b.value['pasajeros'] as int;
      return pasajerosA < pasajerosB ? a : b;
    });

    return '${entrada.key} (${entrada.value['pasajeros']} pasajeros)';
  }

  double _obtenerPromedioPasajerosPorSalida() {
    if (_estadisticasPorHorario.isEmpty) return 0;

    int totalPasajeros = 0;
    for (var stat in _estadisticasPorHorario.values) {
      totalPasajeros += stat['pasajeros'] as int;
    }

    return totalPasajeros / _estadisticasPorHorario.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estadísticas de Pasajeros'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarEstadisticas,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Controles de filtros y vista
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Column(
                    children: [
                      // Pestañas de vista
                      _buildVistaTabs(),
                      SizedBox(height: 16),
                      // Filtros
                      Row(
                        children: [
                          Expanded(child: _buildFiltroTemporal()),
                          SizedBox(width: 16),
                          Expanded(child: _buildFiltroTipo()),
                        ],
                      ),
                    ],
                  ),
                ),

                // Contenido
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContenidoSegunVista(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVistaTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildVistaTab(
            'Pasajeros',
            Icons.people,
            VistaEstadisticas.pasajeros,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildVistaTab(
            'Mixto',
            Icons.analytics,
            VistaEstadisticas.mixto,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildVistaTab(
            'Monetario',
            Icons.attach_money,
            VistaEstadisticas.monetario,
          ),
        ),
      ],
    );
  }

  Widget _buildVistaTab(String label, IconData icon, VistaEstadisticas vista) {
    bool isSelected = _vistaActual == vista;

    return InkWell(
      onTap: () => setState(() => _vistaActual = vista),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroTemporal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Período',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<FiltroTemporal>(
              isExpanded: true,
              value: _filtroTemporal,
              items: [
                DropdownMenuItem(
                  value: FiltroTemporal.hoy,
                  child: Text('Hoy'),
                ),
                DropdownMenuItem(
                  value: FiltroTemporal.semanal,
                  child: Text('Última Semana'),
                ),
                DropdownMenuItem(
                  value: FiltroTemporal.mensual,
                  child: Text('Último Mes'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filtroTemporal = value);
                  _cargarEstadisticas();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroTipo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de Pasaje',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<FiltroTipo>(
              isExpanded: true,
              value: _filtroTipo,
              items: [
                DropdownMenuItem(
                  value: FiltroTipo.ambos,
                  child: Text('Todos'),
                ),
                DropdownMenuItem(
                  value: FiltroTipo.puntoAPunto,
                  child: Text('Punto a Punto'),
                ),
                DropdownMenuItem(
                  value: FiltroTipo.intermedio,
                  child: Text('Intermedio'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filtroTipo = value);
                  _cargarEstadisticas();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContenidoSegunVista() {
    switch (_vistaActual) {
      case VistaEstadisticas.pasajeros:
        return _buildVistaPasajeros();
      case VistaEstadisticas.mixto:
        return _buildVistaMixta();
      case VistaEstadisticas.monetario:
        return _buildVistaMonetaria();
    }
  }

  Widget _buildVistaPasajeros() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResumenGeneral(mostrarMonetario: false),
        SizedBox(height: 24),
        _buildGraficoPastel(),
        SizedBox(height: 24),
        _buildEstadisticasPorHorario(mostrarMonetario: false),
      ],
    );
  }

  Widget _buildVistaMixta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResumenGeneral(mostrarMonetario: true),
        SizedBox(height: 24),
        _buildGraficoPastel(),
        SizedBox(height: 24),
        _buildEstadisticasPorHorario(mostrarMonetario: true),
      ],
    );
  }

  Widget _buildVistaMonetaria() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResumenMonetario(),
        SizedBox(height: 24),
        _buildEstadisticasPorHorario(mostrarMonetario: true),
      ],
    );
  }

  Widget _buildResumenGeneral({required bool mostrarMonetario}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen General',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            _buildResumenItem(
              Icons.people,
              'Total de Pasajeros',
              _totalPasajeros.toString(),
              Colors.blue,
            ),
            if (mostrarMonetario) ...[
              SizedBox(height: 12),
              _buildResumenItem(
                Icons.attach_money,
                'Total Recaudado',
                NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(_totalVentas),
                Colors.green,
              ),
              SizedBox(height: 12),
              _buildResumenItem(
                Icons.trending_up,
                'Promedio por Pasajero',
                NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                    .format(_totalPasajeros > 0 ? _totalVentas / _totalPasajeros : 0),
                Colors.orange,
              ),
            ],
            SizedBox(height: 12),
            _buildResumenItem(
              Icons.schedule,
              'Promedio por Salida',
              _obtenerPromedioPasajerosPorSalida().toStringAsFixed(1) + ' pasajeros',
              Colors.purple,
            ),
            SizedBox(height: 12),
            _buildResumenItem(
              Icons.arrow_upward,
              'Mayor Demanda',
              _obtenerHorarioMayorDemanda(),
              Colors.red,
            ),
            SizedBox(height: 12),
            _buildResumenItem(
              Icons.arrow_downward,
              'Menor Demanda',
              _obtenerHorarioMenorDemanda(),
              Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenMonetario() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen Monetario',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),
            _buildResumenItem(
              Icons.attach_money,
              'Total Recaudado',
              NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(_totalVentas),
              Colors.green,
            ),
            SizedBox(height: 12),
            _buildResumenItem(
              Icons.people,
              'Número de Pasajeros',
              _totalPasajeros.toString(),
              Colors.blue,
            ),
            SizedBox(height: 12),
            _buildResumenItem(
              Icons.trending_up,
              'Valor Promedio',
              NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                  .format(_totalPasajeros > 0 ? _totalVentas / _totalPasajeros : 0),
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGraficoPastel() {
    if (_pasajerosPorTipo.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No hay datos para mostrar',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    // Colores por defecto si no se han cargado
    List<Color> coloresPorDefecto = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
      Colors.indigo.shade400,
    ];

    List<PieChartData> chartData = [];
    int colorIndex = 0;

    _pasajerosPorTipo.forEach((tipo, cantidad) {
      // Usar color de tarifa si está disponible, sino usar color por defecto
      Color color = _coloresTarifas[tipo] ?? coloresPorDefecto[colorIndex % coloresPorDefecto.length];

      chartData.add(PieChartData(
        label: tipo,
        value: cantidad.toDouble(),
        color: color,
      ));
      colorIndex++;
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribución por Tipo de Pasajero',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 24),
            PieChartWidget(data: chartData, size: 180),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasPorHorario({required bool mostrarMonetario}) {
    if (_estadisticasPorHorario.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No hay datos de horarios',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    // Ordenar horarios
    var horariosOrdenados = _estadisticasPorHorario.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas por Horario',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            ...horariosOrdenados.map((entry) {
              String horario = entry.key;
              int pasajeros = entry.value['pasajeros'] as int;
              double total = entry.value['total'] as double;

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.blue.shade700, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              horario,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '$pasajeros pasajero${pasajeros != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (mostrarMonetario)
                        Text(
                          NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(total),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
