import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bus_ticket_generator.dart';
import '../widgets/numeric_input_field.dart';
import '../widgets/horario_input_field.dart';
import '../widgets/date_input_field.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/bus_seat_map.dart';
import '../models/tarifa.dart';
import '../models/auth_provider.dart';
import '../database/app_database.dart';
import 'package:intl/intl.dart';

class VentaBusScreen extends StatefulWidget {
  @override
  _VentaBusScreenState createState() => _VentaBusScreenState();
}

class _VentaBusScreenState extends State<VentaBusScreen> {
  String destino = 'Aysen';
  final List<String> destinos = ['Aysen', 'Intermedio', 'Coyhaique'];
  String? kilometroIntermedio;
  String origenIntermedio = 'Aysen';

  String? horarioSeleccionado;
  String? asientoSeleccionado;
  String valorBoleto = '0';
  bool _isLoading = false;

  String tipoDia = 'LUNES A SÁBADO';
  final List<String> tiposDia = ['LUNES A SÁBADO', 'DOMINGO / FERIADO'];
  List<Tarifa> tarifasDisponibles = [];
  Tarifa? tarifaSeleccionada;

  // Para gestión de asientos
  int? salidaId;
  Set<int> asientosOcupados = {};
  String fechaSeleccionada = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final ScrollController _scrollController = ScrollController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FocusNode _fechaFocusNode = FocusNode();
  final FocusNode _horarioFocusNode = FocusNode();
  final FocusNode _asientoFocusNode = FocusNode();
  final FocusNode _valorFocusNode = FocusNode();
  final FocusNode _kmIntermedioFocusNode = FocusNode();

  String? fechaEscrita; // Fecha en formato DD/MM/AA

  @override
  void initState() {
    super.initState();
    _cargarTarifas();

    // Atajos de teclado - iniciar en fecha
    ServicesBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fechaFocusNode.requestFocus();
      }
    });
  }

  Future<void> _cargarTarifas() async {
    try {
      final tarifas = await AppDatabase.instance.getTarifasByTipoDia(tipoDia);
      List<Tarifa> todasTarifas = tarifas.map((map) => Tarifa.fromMap(map)).toList();

      setState(() {
        // Filtrar tarifas según el destino seleccionado
        if (destino == 'Intermedio') {
          // Si el destino es Intermedio, mostrar SOLO las tarifas que contengan "INTERMEDIO" en el nombre
          tarifasDisponibles = todasTarifas
              .where((t) => t.categoria.toUpperCase().contains('INTERMEDIO'))
              .toList();
        } else {
          // Si el destino NO es Intermedio, NO mostrar las tarifas de Intermedio
          tarifasDisponibles = todasTarifas
              .where((t) => !t.categoria.toUpperCase().contains('INTERMEDIO'))
              .toList();
        }

        // Reseleccionar tarifa si la anterior ya no está disponible
        if (tarifasDisponibles.isNotEmpty) {
          if (tarifaSeleccionada == null || !tarifasDisponibles.contains(tarifaSeleccionada)) {
            tarifaSeleccionada = tarifasDisponibles.first;
            valorBoleto = tarifaSeleccionada!.valor.toStringAsFixed(0);
          }
        } else {
          tarifaSeleccionada = null;
          valorBoleto = '0';
        }
      });
    } catch (e) {
      _mostrarError('Error al cargar tarifas: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  String? _validarHorario(String value) {
    if (value.isEmpty) return 'Ingrese un horario';
    if (!RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value)) {
      return 'Formato inválido (HH:MM)';
    }
    return null;
  }

  String? _validarAsiento(String value) {
    if (value.isEmpty) return 'Ingrese un asiento';
    int? asiento = int.tryParse(value);
    if (asiento == null || asiento < 1 || asiento > 45) {
      return 'Asiento inválido (1-45)';
    }
    return null;
  }

  String? _validarValor(String value) {
    if (value.isEmpty) return 'Ingrese un valor';
    int? valor = int.tryParse(value);
    if (valor == null || valor <= 0) {
      return 'Valor debe ser mayor a 0';
    }
    return null;
  }

  void _confirmarVenta() async {
    if (!_formKey.currentState!.validate()) return;

    if (tarifaSeleccionada == null) {
      _mostrarError('Por favor seleccione una tarifa');
      return;
    }

    if (horarioSeleccionado == null || asientoSeleccionado == null || int.parse(valorBoleto) <= 0) {
      _mostrarError('Por favor complete todos los campos correctamente');
      return;
    }

    if (destino == 'Intermedio' && (kilometroIntermedio == null || kilometroIntermedio!.isEmpty)) {
      _mostrarError('Por favor ingrese el kilómetro intermedio');
      return;
    }

    // Verificar que el asiento no esté ocupado
    final numAsiento = int.tryParse(asientoSeleccionado!);
    if (numAsiento != null && asientosOcupados.contains(numAsiento)) {
      _mostrarError('El asiento $asientoSeleccionado ya está ocupado');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        tipoDia: tipoDia,
        tarifa: tarifaSeleccionada!.categoria,
        destino: destino,
        origen: origenIntermedio,
        kilometro: kilometroIntermedio,
        horario: horarioSeleccionado!,
        asiento: asientoSeleccionado!,
        valor: valorBoleto,
      ),
    );

    if (confirmar == true) {
      // Mostrar diálogo de método de pago
      final paymentResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => PaymentMethodDialog(
          totalAmount: double.parse(valorBoleto),
        ),
      );

      if (paymentResult == null) return; // Usuario canceló el pago

      setState(() => _isLoading = true);

      try {
        String destinoFormateado = destino;
        if (destino == 'Intermedio' && kilometroIntermedio != null) {
          destinoFormateado = '$origenIntermedio - Intermedio Km $kilometroIntermedio';
        }

        final comprobante = await BusTicketGenerator.generateAndPrintTicket(
          destino: destinoFormateado,
          horario: horarioSeleccionado!,
          asiento: asientoSeleccionado!,
          valor: valorBoleto,
          tipoDia: tipoDia,
          tituloTarifa: tarifaSeleccionada?.categoria ?? 'PUBLICO GENERAL',
          origen: destino == 'Intermedio' ? origenIntermedio : null,
          kilometros: destino == 'Intermedio' ? kilometroIntermedio : null,
          metodoPago: paymentResult['metodo'],
          montoEfectivo: paymentResult['montoEfectivo'],
          montoTarjeta: paymentResult['montoTarjeta'],
        );

        // Reservar el asiento en la base de datos
        if (salidaId != null) {
          await AppDatabase.instance.reservarAsiento(
            salidaId: salidaId!,
            numeroAsiento: int.parse(asientoSeleccionado!),
            comprobante: comprobante,
          );
          // Recargar asientos ocupados
          await _cargarAsientosOcupados();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket generado exitosamente'), backgroundColor: Colors.green),
        );

        setState(() {
          horarioSeleccionado = null;
          asientoSeleccionado = null;
          valorBoleto = tarifaSeleccionada?.valor.toStringAsFixed(0) ?? '0';
        });

        _horarioFocusNode.requestFocus();
      } catch (e) {
        _mostrarError('Error al generar el ticket: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cargarAsientosOcupados() async {
    if (horarioSeleccionado == null || horarioSeleccionado!.isEmpty) return;

    try {
      // Crear o obtener la salida
      final id = await AppDatabase.instance.crearObtenerSalida(
        fecha: fechaSeleccionada,
        horario: horarioSeleccionado!,
        destino: destino,
        tipoDia: tipoDia,
      );

      // Obtener asientos ocupados
      final asientos = await AppDatabase.instance.getAsientosOcupados(id);
      setState(() {
        salidaId = id;
        asientosOcupados = asientos.map((a) => a['numero_asiento'] as int).toSet();
      });
    } catch (e) {
      _mostrarError('Error al cargar asientos: $e');
    }
  }

  void _onAsientoSeleccionado(int asiento) {
    setState(() {
      asientoSeleccionado = asiento.toString().padLeft(2, '0');
    });
    _asientoFocusNode.requestFocus();
  }

  void _autoScrollToAsiento() {
    // Hacer scroll hacia el campo de asiento
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      _asientoFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _fechaFocusNode.dispose();
    _horarioFocusNode.dispose();
    _asientoFocusNode.dispose();
    _valorFocusNode.dispose();
    _kmIntermedioFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Venta de Boletos de Bus'),
        centerTitle: false,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'F1: Confirmar | ESC: Cancelar',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // Panel izquierdo - Mapa de asientos ESTÁTICO
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.grey.shade100,
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Mapa de Asientos'),
                      SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          child: BusSeatMap(
                            selectedSeat: asientoSeleccionado != null && asientoSeleccionado!.isNotEmpty
                                ? int.tryParse(asientoSeleccionado!)
                                : null,
                            occupiedSeats: asientosOcupados,
                            onSeatTap: _onAsientoSeleccionado,
                            tipoDia: tipoDia,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Panel derecho - TODOS los controles
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Configuración del Viaje'),
                          SizedBox(height: 16),

                          // Destino
                          _buildLabel('Destino'),
                          _buildSegmentedButton(
                            destinos,
                            destino,
                                (value) {
                              setState(() {
                                destino = value;
                                if (value != 'Intermedio') kilometroIntermedio = null;
                              });
                              // Recargar tarifas cuando cambie el destino
                              _cargarTarifas();
                            },
                          ),

                          // Origen para intermedio
                          if (destino == 'Intermedio') ...[
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Origen del Viaje', color: Colors.blue.shade700),
                                  SizedBox(height: 8),
                                  _buildSegmentedButton(
                                    ['Aysen', 'Coyhaique'],
                                    origenIntermedio,
                                        (value) {
                                      setState(() {
                                        origenIntermedio = value;
                                        horarioSeleccionado = null;
                                      });
                                    },
                                    compact: true,
                                  ),
                                  SizedBox(height: 12),
                                  _buildLabel('Kilómetro Intermedio', color: Colors.blue.shade700),
                                  SizedBox(height: 8),
                                  NumericInputField(
                                    value: kilometroIntermedio,
                                    hintText: 'Ej: 20 (máx. 64)',
                                    focusNode: _kmIntermedioFocusNode,
                                    validator: (value) {
                                      if (value.isEmpty) return 'Ingrese el kilómetro';
                                      int? km = int.tryParse(value);
                                      if (km == null || km <= 0 || km > 64) {
                                        return 'Debe estar entre 1 y 64';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      if (value.length <= 2 && int.tryParse(value) != null) {
                                        int km = int.parse(value);
                                        if (km <= 64) setState(() => kilometroIntermedio = value);
                                      }
                                    },
                                    onEnterPressed: () => _horarioFocusNode.requestFocus(),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: 24),

                          // Fecha de salida
                          _buildLabel('Fecha de Salida'),
                          InkWell(
                            onTap: () async {
                              final fechaLimite = DateTime.now().add(Duration(days: 35)); // 5 semanas
                              final fechaPick = await showDatePicker(
                                context: context,
                                initialDate: DateTime.parse(fechaSeleccionada),
                                firstDate: DateTime.now(),
                                lastDate: fechaLimite,
                                locale: const Locale('es', 'ES'),
                              );
                              if (fechaPick != null) {
                                setState(() {
                                  fechaSeleccionada = DateFormat('yyyy-MM-dd').format(fechaPick);
                                  horarioSeleccionado = null;
                                  asientoSeleccionado = null;
                                  salidaId = null;
                                  asientosOcupados.clear();
                                });
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('EEEE, dd MMMM yyyy', 'es_ES').format(DateTime.parse(fechaSeleccionada)),
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade700),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 24),

                          // Tipo de día
                          _buildLabel('Tipo de Día'),
                          _buildSegmentedButton(
                            tiposDia,
                            tipoDia,
                                (value) {
                              setState(() {
                                tipoDia = value;
                                tarifaSeleccionada = null;
                              });
                              _cargarTarifas();
                            },
                          ),

                          SizedBox(height: 24),

                          // Categoría de tarifa
                          _buildLabel('Categoría de Tarifa'),
                          if (tarifasDisponibles.isEmpty)
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(
                                'No hay tarifas disponibles',
                                style: TextStyle(color: Colors.orange.shade700),
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Tarifa>(
                                  isExpanded: true,
                                  value: tarifaSeleccionada,
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  items: tarifasDisponibles.map((tarifa) {
                                    return DropdownMenuItem<Tarifa>(
                                      value: tarifa,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(tarifa.categoria),
                                          Text(
                                            '\$${tarifa.valor.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (tarifa) {
                                    setState(() {
                                      tarifaSeleccionada = tarifa;
                                      if (tarifa != null) {
                                        valorBoleto = tarifa.valor.toStringAsFixed(0);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),

                          SizedBox(height: 24),

                          // Fecha de salida (selector visual)
                          _buildLabel('Fecha de Salida (Selector)'),
                          InkWell(
                            onTap: () async {
                              final fechaLimite = DateTime.now().add(Duration(days: 35)); // 5 semanas
                              final fechaPick = await showDatePicker(
                                context: context,
                                initialDate: DateTime.parse(fechaSeleccionada),
                                firstDate: DateTime.now(),
                                lastDate: fechaLimite,
                                locale: const Locale('es', 'ES'),
                              );
                              if (fechaPick != null) {
                                setState(() {
                                  fechaSeleccionada = DateFormat('yyyy-MM-dd').format(fechaPick);
                                  horarioSeleccionado = null;
                                  asientoSeleccionado = null;
                                  salidaId = null;
                                  asientosOcupados.clear();
                                });
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('EEEE, dd MMMM yyyy', 'es_ES').format(DateTime.parse(fechaSeleccionada)),
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade700),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 32),
                          _buildSectionTitle('Datos del Boleto'),
                          SizedBox(height: 16),

                          // Recuadro guía del boleto
                          _buildTicketPreview(),
                          SizedBox(height: 24),

                          // CAMPO DE FECHA ESCRITA (050825 -> 05/08/25)
                          _buildLabel('Fecha (Escribir)'),
                          DateInputField(
                            value: fechaEscrita,
                            focusNode: _fechaFocusNode,
                            validator: (value) {
                              if (value.isEmpty) return null; // Opcional
                              if (value.length != 8) return 'Formato: DD/MM/AA';
                              return null;
                            },
                            onChanged: (value) {
                              setState(() => fechaEscrita = value);
                            },
                            onEnterPressed: () {
                              // Auto-scroll al horario
                              _autoScrollToAsiento();
                              _horarioFocusNode.requestFocus();
                            },
                          ),

                          SizedBox(height: 24),

                          // HORARIO (vertical)
                          _buildLabel('Horario de Salida'),
                          HorarioInputField(
                            value: horarioSeleccionado,
                            destino: destino,
                            origenIntermedio: origenIntermedio,
                            fechaSeleccionada: fechaSeleccionada,
                            validator: _validarHorario,
                            focusNode: _horarioFocusNode,
                            onChanged: (value) {
                              setState(() => horarioSeleccionado = value);
                              _cargarAsientosOcupados();
                            },
                            onEnterPressed: () {
                              _autoScrollToAsiento();
                              _asientoFocusNode.requestFocus();
                            },
                          ),

                          SizedBox(height: 24),

                          // ASIENTO (vertical)
                          _buildLabel('Número de Asiento'),
                          NumericInputField(
                            label: '',
                            value: asientoSeleccionado,
                            hintText: '01-45',
                            validator: _validarAsiento,
                            focusNode: _asientoFocusNode,
                            onChanged: (value) => setState(() => asientoSeleccionado = value),
                            onEnterPressed: () {
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              if (authProvider.isSecretaria) {
                                _confirmarVenta();
                              } else {
                                _valorFocusNode.requestFocus();
                              }
                            },
                          ),

                          SizedBox(height: 24),

                          // Valor del boleto - Para administradores con teclado, para secretarias panel de tarifas
                          Builder(
                            builder: (context) {
                              final authProvider = Provider.of<AuthProvider>(context);
                              if (authProvider.isSecretaria) {
                                // Secretarias: mostrar panel de selección de tarifas
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Seleccionar Tarifa'),
                                    if (tarifasDisponibles.isEmpty)
                                      Container(
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.orange.shade200),
                                        ),
                                        child: Text(
                                          'No hay tarifas disponibles',
                                          style: TextStyle(color: Colors.orange.shade700),
                                        ),
                                      )
                                    else
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<Tarifa>(
                                            isExpanded: true,
                                            value: tarifaSeleccionada,
                                            padding: EdgeInsets.symmetric(horizontal: 12),
                                            items: tarifasDisponibles.map((tarifa) {
                                              return DropdownMenuItem<Tarifa>(
                                                value: tarifa,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(tarifa.categoria),
                                                    Text(
                                                      '\$${tarifa.valor.toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blue.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (tarifa) {
                                              setState(() {
                                                tarifaSeleccionada = tarifa;
                                                if (tarifa != null) {
                                                  valorBoleto = tarifa.valor.toStringAsFixed(0);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              } else {
                                // Administradores: mostrar teclado numérico
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Valor del Boleto'),
                                    NumericInputField(
                                      label: '',
                                      value: valorBoleto == '0' ? '' : valorBoleto,
                                      hintText: 'Ingrese valor',
                                      prefix: '\$',
                                      validator: _validarValor,
                                      focusNode: _valorFocusNode,
                                      onChanged: (value) => setState(() => valorBoleto = value),
                                      onEnterPressed: _confirmarVenta,
                                      showKeyboard: true,
                                    ),
                                  ],
                                );
                              }
                            },
                          ),

                          SizedBox(height: 32),

                          // Botón de generar
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _confirmarVenta,
                              icon: Icon(Icons.print),
                              label: Text('GENERAR TICKET (F1)', style: TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Overlay de carga
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 24),
                        Text('Generando ticket...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Por favor espere', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTicketPreview() {
    final ahora = DateTime.now();
    final esHoy = fechaSeleccionada == DateTime(ahora.year, ahora.month, ahora.day)
        .toString().split(' ')[0];
    final isDomingoFeriado = tipoDia == 'DOMINGO / FERIADO';

    String origenTexto = destino == 'Coyhaique' ? 'Aysén' : 'Coyhaique';
    String destinoTexto = destino;

    if (destino == 'Intermedio' && kilometroIntermedio != null && kilometroIntermedio!.isNotEmpty) {
      origenTexto = origenIntermedio;
      destinoTexto = 'Int. Km $kilometroIntermedio';
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDomingoFeriado
            ? [Colors.red.shade50, Colors.red.shade100]
            : [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDomingoFeriado ? Colors.red.shade300 : Colors.blue.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number,
                color: isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'RESUMEN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
                ),
              ),
              if (esHoy) ...[
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDomingoFeriado ? Colors.red.shade600 : Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'HOY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8),

          // Origen → Destino en una línea
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                origenTexto,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward,
                  color: isDomingoFeriado ? Colors.red.shade600 : Colors.blue.shade600,
                  size: 14,
                ),
              ),
              Text(
                destinoTexto,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800,
                ),
              ),
            ],
          ),

          SizedBox(height: 8),
          Divider(color: isDomingoFeriado ? Colors.red.shade300 : Colors.blue.shade300, height: 1),
          SizedBox(height: 8),

          // Detalles en grid compacto
          Row(
            children: [
              Expanded(
                child: _buildPreviewItemCompact(
                  DateFormat('dd/MM', 'es_ES').format(DateTime.parse(fechaSeleccionada)),
                  Icons.calendar_today,
                  isDomingoFeriado,
                ),
              ),
              Expanded(
                child: _buildPreviewItemCompact(
                  horarioSeleccionado ?? '--:--',
                  Icons.access_time,
                  isDomingoFeriado,
                ),
              ),
              Expanded(
                child: _buildPreviewItemCompact(
                  asientoSeleccionado ?? '--',
                  Icons.event_seat,
                  isDomingoFeriado,
                ),
              ),
              Expanded(
                child: _buildPreviewItemCompact(
                  '\$${valorBoleto != '0' ? valorBoleto : '--'}',
                  Icons.attach_money,
                  isDomingoFeriado,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItemCompact(String value, IconData icon, bool isDomingoFeriado) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 12,
          color: isDomingoFeriado ? Colors.red.shade600 : Colors.blue.shade600,
        ),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
    );
  }

  Widget _buildLabel(String label, {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color ?? Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildSegmentedButton(List<String> options, String selected, Function(String) onSelect, {bool compact = false}) {
    return Container(
      height: compact ? 40 : 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: options.map((option) {
          bool isSelected = selected == option;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(option),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.blue.shade700 : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String tipoDia, tarifa, destino, origen, horario, asiento, valor;
  final String? kilometro;

  const _ConfirmDialog({
    required this.tipoDia,
    required this.tarifa,
    required this.destino,
    required this.origen,
    required this.horario,
    required this.asiento,
    required this.valor,
    this.kilometro,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.confirmation_number, color: Colors.blue),
          SizedBox(width: 12),
          Text('Confirmar Venta'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow('Tipo de día:', tipoDia),
          _buildRow('Tarifa:', tarifa),
          Divider(),
          if (destino == 'Intermedio') _buildRow('Origen:', origen),
          _buildRow('Destino:', destino == 'Intermedio' ? '$destino (Km ${kilometro ?? "?"})' : destino),
          _buildRow('Salida:', horario),
          _buildRow('Asiento:', asiento),
          _buildRow('Valor:', '\$$valor', bold: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('CANCELAR'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: Icon(Icons.check),
          label: Text('CONFIRMAR'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          SizedBox(width: 16),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}