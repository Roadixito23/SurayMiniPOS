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
import '../models/horario.dart';
import '../database/app_database.dart';
import 'package:intl/intl.dart';

class VentaBusScreen extends StatefulWidget {
  @override
  _VentaBusScreenState createState() => _VentaBusScreenState();
}

class _VentaBusScreenState extends State<VentaBusScreen> {
  final HorarioManager _horarioManager = HorarioManager();

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
  final FocusNode _scrollFocusNode = FocusNode();

  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();
  final TextEditingController _asientoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();

  String? fechaEscrita; // Fecha en formato DD/MM/AA

  @override
  void initState() {
    super.initState();
    _cargarTarifas();

    // Inicializar fecha actual en formato DD/MM/AA
    final ahora = DateTime.now();
    fechaEscrita = DateFormat('ddMMyy').format(ahora);
    _fechaController.text = DateFormat('dd/MM/yy').format(ahora);

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
          tarifasDisponibles = todasTarifas
              .where((t) => t.categoria.toUpperCase().contains('INTERMEDIO'))
              .toList();
        } else {
          tarifasDisponibles = todasTarifas
              .where((t) => !t.categoria.toUpperCase().contains('INTERMEDIO'))
              .toList();
        }

        // Reseleccionar tarifa si la anterior ya no está disponible
        if (tarifasDisponibles.isNotEmpty) {
          if (tarifaSeleccionada == null || !tarifasDisponibles.contains(tarifaSeleccionada)) {
            tarifaSeleccionada = tarifasDisponibles.first;
            valorBoleto = tarifaSeleccionada!.valor.toStringAsFixed(0);
            _valorController.text = valorBoleto;
          }
        } else {
          tarifaSeleccionada = null;
          valorBoleto = '0';
          _valorController.clear();
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

  String? _validarHorario(String? value) {
    if (value == null || value.isEmpty) return 'Ingrese un horario';
    if (!RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value)) {
      return 'Formato inválido (HH:MM)';
    }
    return null;
  }

  String? _validarAsiento(String? value) {
    if (value==null || value.isEmpty) return 'Ingrese un asiento';
    int? asiento = int.tryParse(value);
    if (asiento == null || asiento < 1 || asiento > 45) {
      return 'Asiento inválido (1-45)';
    }
    return null;
  }

  // Método para mostrar selector de horarios
  Future<void> _mostrarSelectorHorarios() async {
    await _horarioManager.cargarHorarios();

    // Determinar qué horarios mostrar según el destino y tipo de día
    String destinoReal = destino == 'Intermedio' ? origenIntermedio : destino;
    String categoria = tipoDia == 'DOMINGO / FERIADO' ? 'DomingosFeriados' :
                       (DateTime.now().weekday == 6 ? 'Sabados' : 'LunesViernes');

    List<String> horariosDisponibles = [];
    if (destinoReal == 'Aysen') {
      horariosDisponibles = _horarioManager.horariosAysen[categoria] ?? [];
    } else {
      horariosDisponibles = _horarioManager.horariosCoyhaique[categoria] ?? [];
    }

    if (horariosDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay horarios configurados para este destino y tipo de día'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo con lista de horarios
    String? horarioSeleccionado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.schedule, color: Colors.blue),
            SizedBox(width: 12),
            Text('Seleccionar Horario'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: horariosDisponibles.length,
            itemBuilder: (context, index) {
              final horario = horariosDisponibles[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.access_time, color: Colors.blue.shade700),
                ),
                title: Text(
                  horario,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                onTap: () => Navigator.pop(context, horario),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hoverColor: Colors.blue.shade50,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR'),
          ),
        ],
      ),
    );

    if (horarioSeleccionado != null) {
      setState(() {
        _horarioController.text = horarioSeleccionado;
        this.horarioSeleccionado = horarioSeleccionado;
      });
      _cargarAsientosOcupados();
      _asientoFocusNode.requestFocus();
    }
  }

  // Manejar eventos de teclado para scroll con flechas
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      const scrollAmount = 50.0;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _scrollController.animateTo(
          _scrollController.offset + scrollAmount,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _scrollController.animateTo(
          _scrollController.offset - scrollAmount,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  String? _validarValor(String? value) {
    if (value == null || value.isEmpty) return 'Ingrese un valor';
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
          _horarioController.clear();
          _asientoController.clear();
          _valorController.text = valorBoleto;
        });

        _horarioFocusNode.requestFocus();
        _autoScrollToField(_horarioFocusNode);
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
      _asientoController.text = asiento.toString().padLeft(2, '0');
    });
    _asientoFocusNode.requestFocus();
  }

  void _autoScrollToField(FocusNode focusNode) {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        final renderObject = focusNode.context?.findRenderObject();
        if (renderObject != null && renderObject is RenderBox) {
          final position = renderObject.localToGlobal(Offset.zero);
          final scrollOffset = position.dy - 200; // Ajustar para centrar mejor
          
          _scrollController.animateTo(
            _scrollController.offset + scrollOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Color _getColorPrimario() {
    return tipoDia == 'DOMINGO / FERIADO' ? Colors.red.shade600 : Colors.blue.shade600;
  }

  Color _getColorSecundario() {
    return tipoDia == 'DOMINGO / FERIADO' ? Colors.red.shade50 : Colors.blue.shade50;
  }

  @override
  void dispose() {
    _fechaFocusNode.dispose();
    _horarioFocusNode.dispose();
    _asientoFocusNode.dispose();
    _valorFocusNode.dispose();
    _kmIntermedioFocusNode.dispose();
    _scrollFocusNode.dispose();
    _fechaController.dispose();
    _horarioController.dispose();
    _asientoController.dispose();
    _valorController.dispose();
    _kmController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDomingoFeriado = tipoDia == 'DOMINGO / FERIADO';

    return Scaffold(
      appBar: AppBar(
        title: Text('Venta de Boletos de Bus'),
        centerTitle: false,
        backgroundColor: _getColorPrimario(),
        actions: [
          // Selector de fecha en AppBar
          InkWell(
            onTap: () async {
              final fechaLimite = DateTime.now().add(Duration(days: 35));
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
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yy', 'es_ES').format(DateTime.parse(fechaSeleccionada)),
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),

          // Switch de tipo de día
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  'LUN-SÁB',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: isDomingoFeriado ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Switch(
                  value: isDomingoFeriado,
                  onChanged: (value) {
                    setState(() {
                      tipoDia = value ? 'DOMINGO / FERIADO' : 'LUNES A SÁBADO';
                      tarifaSeleccionada = null;
                    });
                    _cargarTarifas();
                  },
                  activeColor: Colors.white,
                  activeTrackColor: Colors.red.shade300,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.blue.shade300,
                ),
                SizedBox(width: 8),
                Text(
                  'DOM/FER',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: isDomingoFeriado ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),

          // Ayuda de teclas
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
      body: RawKeyboardListener(
        focusNode: _scrollFocusNode,
        onKey: _handleKeyEvent,
        child: Stack(
          children: [
          Row(
            children: [
              // Panel izquierdo - Mapa de asientos COMPACTO
              Expanded(
                flex: 2,
                child: Container(
                  color: _getColorSecundario(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Resumen compacto arriba
                      _buildTicketPreviewCompact(),
                      SizedBox(height: 12),
                      Divider(),
                      SizedBox(height: 8),
                      
                      _buildSectionTitle('Mapa de Asientos', isDomingoFeriado),
                      SizedBox(height: 12),
                      
                      // Mapa de asientos con tamaño controlado
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: constraints.maxHeight * 0.95,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.contain,
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
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Panel derecho - Controles
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
                          _buildSectionTitle('Configuración del Viaje', isDomingoFeriado),
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
                              _cargarTarifas();
                            },
                            isDomingoFeriado,
                          ),

                          // Origen para intermedio
                          if (destino == 'Intermedio') ...[
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _getColorSecundario(),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getColorPrimario().withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Origen del Viaje', color: _getColorPrimario()),
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
                                    isDomingoFeriado,
                                    compact: true,
                                  ),
                                  SizedBox(height: 12),
                                  _buildLabel('Kilómetro Intermedio', color: _getColorPrimario()),
                                  SizedBox(height: 8),
                                  TextFormField(
                                    controller: _kmController,
                                    focusNode: _kmIntermedioFocusNode,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'Ej: 20 (máx. 64)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Ingrese el kilómetro';
                                      int? km = int.tryParse(value);
                                      if (km == null || km <= 0 || km > 64) {
                                        return 'Debe estar entre 1 y 64';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      if (value.isNotEmpty) {
                                        int? km = int.tryParse(value);
                                        if (km != null && km <= 64) {
                                          setState(() => kilometroIntermedio = value);
                                        }
                                      }
                                    },
                                    onFieldSubmitted: (_) {
                                      _horarioFocusNode.requestFocus();
                                      _autoScrollToField(_horarioFocusNode);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: 24),
                          _buildSectionTitle('Datos del Boleto', isDomingoFeriado),
                          SizedBox(height: 16),

                          // CAMPO DE FECHA ESCRITA (050825 -> 05/08/25)
                          _buildLabel('Fecha (Escribir)'),
                          TextFormField(
                            controller: _fechaController,
                            focusNode: _fechaFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                              _DateInputFormatter(),
                            ],
                            decoration: InputDecoration(
                              hintText: 'DD/MM/AA',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onTap: () {
                              // Seleccionar todo el texto al hacer click
                              _fechaController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _fechaController.text.length,
                              );
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) return null; // Opcional
                              String cleaned = value.replaceAll('/', '');
                              if (cleaned.length != 6) return 'Formato: DD/MM/AA';
                              return null;
                            },
                            onChanged: (value) {
                              setState(() => fechaEscrita = value.replaceAll('/', ''));
                            },
                            onFieldSubmitted: (_) {
                              _horarioFocusNode.requestFocus();
                              _autoScrollToField(_horarioFocusNode);
                            },
                          ),

                          SizedBox(height: 24),

                          // HORARIO (vertical) - Ahora usa selector de dropdown
                          _buildLabel('Horario de Salida'),
                          InkWell(
                            onTap: _mostrarSelectorHorarios,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                hintText: 'Seleccionar horario',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                              child: Text(
                                _horarioController.text.isEmpty ? 'Seleccionar horario' : _horarioController.text,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _horarioController.text.isEmpty ? Colors.grey.shade600 : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          // Campo oculto para validación
                          TextFormField(
                            controller: _horarioController,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              constraints: BoxConstraints(maxHeight: 0),
                            ),
                            style: TextStyle(height: 0),
                            validator: _validarHorario,
                          ),

                          SizedBox(height: 24),

                          // ASIENTO (vertical) - MODIFICADO PARA NO AUTO-SELECCIONAR
                          _buildLabel('Número de Asiento'),
                          TextFormField(
                            controller: _asientoController,
                            focusNode: _asientoFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: InputDecoration(
                              hintText: '01-45',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onTap: () {
                              _asientoController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _asientoController.text.length,
                              );
                            },
                            validator: _validarAsiento,
                            onChanged: (value) {
                              setState(() => asientoSeleccionado = value);
                            },
                            onFieldSubmitted: (_) {
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              if (authProvider.isSecretaria) {
                                _confirmarVenta();
                              } else {
                                _valorFocusNode.requestFocus();
                                _autoScrollToField(_valorFocusNode);
                              }
                            },
                          ),

                          SizedBox(height: 24),

                          // Valor del boleto
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
                                                        color: _getColorPrimario(),
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
                                                  _valorController.text = valorBoleto;
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
                                    TextFormField(
                                      controller: _valorController,
                                      focusNode: _valorFocusNode,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: InputDecoration(
                                        hintText: 'Ingrese valor',
                                        prefixText: '\$ ',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                      onTap: () {
                                        _valorController.selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset: _valorController.text.length,
                                        );
                                      },
                                      validator: _validarValor,
                                      onChanged: (value) => setState(() => valorBoleto = value),
                                      onFieldSubmitted: (_) => _confirmarVenta(),
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
                                backgroundColor: _getColorPrimario(),
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
      ),
    );
  }

  Widget _buildTicketPreviewCompact() {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDomingoFeriado ? Colors.red.shade300 : Colors.blue.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Origen → Destino
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                origenTexto,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: isDomingoFeriado ? Colors.red.shade600 : Colors.blue.shade600,
                  size: 16,
                ),
              ),
              Text(
                destinoTexto,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800,
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          // Detalles compactos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoChip(
                horarioSeleccionado ?? '--:--',
                Icons.access_time,
                isDomingoFeriado,
              ),
              _buildInfoChip(
                'A-${asientoSeleccionado ?? '--'}',
                Icons.event_seat,
                isDomingoFeriado,
              ),
              _buildInfoChip(
                '\$${valorBoleto != '0' ? valorBoleto : '--'}',
                Icons.attach_money,
                isDomingoFeriado,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, bool isDomingoFeriado) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDomingoFeriado ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
          ),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDomingoFeriado) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800,
      ),
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

  Widget _buildSegmentedButton(
    List<String> options,
    String selected,
    Function(String) onSelect,
    bool isDomingoFeriado,
    {bool compact = false}
  ) {
    final colorPrimario = isDomingoFeriado ? Colors.red.shade100 : Colors.blue.shade100;
    final colorTexto = isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700;

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
                  color: isSelected ? colorPrimario : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? colorTexto : Colors.black87,
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

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text.replaceAll('/', '');

    if (text.length > 6) {
      return oldValue;
    }

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '/';
      }
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text.replaceAll(':', '');

    if (text.length > 4) {
      return oldValue;
    }

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        formatted += ':';
      }
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
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