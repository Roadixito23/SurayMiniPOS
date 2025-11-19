import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bus_ticket_generator.dart';
import '../widgets/numeric_input_field.dart';
import '../widgets/horario_input_field.dart';
import '../widgets/date_input_field.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/bus_seat_map.dart';
import '../widgets/horario_selector_dialog.dart';
import '../widgets/tarifa_selector_dialog.dart';
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

  // Origen del viaje para todos los destinos (no solo intermedio)
  String origenViaje = 'Coyhaique'; // Por defecto desde Coyhaique

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

  // Método para verificar si un horario ya pasó
  bool _horarioPasado(String horario) {
    // Solo deshabilitar si la fecha seleccionada es hoy
    final fechaSeleccionadaDate = DateTime.parse(fechaSeleccionada);
    final hoy = DateTime.now();

    if (fechaSeleccionadaDate.year != hoy.year ||
        fechaSeleccionadaDate.month != hoy.month ||
        fechaSeleccionadaDate.day != hoy.day) {
      return false; // No es hoy, todos los horarios están disponibles
    }

    // Es hoy, verificar si el horario ya pasó
    final partes = horario.split(':');
    if (partes.length != 2) return false;

    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);

    if (hora == null || minuto == null) return false;

    final horarioDateTime = DateTime(hoy.year, hoy.month, hoy.day, hora, minuto);
    return horarioDateTime.isBefore(hoy);
  }

  // Método para mostrar selector de horarios con navegación por teclado
  Future<void> _mostrarSelectorHorarios() async {
    await _horarioManager.cargarHorarios();

    // Determinar qué horarios mostrar según el destino y tipo de día
    String destinoReal = destino == 'Intermedio' ? origenIntermedio : destino;
    String categoria = tipoDia == 'DOMINGO / FERIADO' ? 'DomingosFeriados' :
                       (DateTime.now().weekday == 6 ? 'Sabados' : 'LunesViernes');

    // Obtener TODOS los horarios (fijos + salidas extras del día)
    List<String> horariosDisponibles = _horarioManager.obtenerHorariosCompletos(destinoReal, categoria);

    if (horariosDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay horarios configurados para este destino y tipo de día'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Filtrar horarios pasados
    List<String> horariosActivos = horariosDisponibles.where((h) => !_horarioPasado(h)).toList();

    if (horariosActivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay horarios disponibles (todos han pasado)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isDomingoFeriado = tipoDia == 'DOMINGO / FERIADO';

    // Mostrar diálogo con navegación por teclado
    String? horarioSeleccionado = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HorarioSelectorDialog(
        horarios: horariosActivos,
        horarioManager: _horarioManager,
        destino: destinoReal,
        categoria: categoria,
        isDomingoFeriado: isDomingoFeriado,
        onAgregarNuevo: () async {
          final nuevoHorario = await _mostrarDialogoRelojDigitalVenta(destinoReal, categoria);
          if (nuevoHorario != null) {
            await _horarioManager.agregarSalidaExtra(nuevoHorario, destinoReal, categoria);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.star, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Salida extra $nuevoHorario agregada (solo para hoy)'),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade700,
              ),
            );
          }
          return nuevoHorario;
        },
      ),
    );

    if (horarioSeleccionado != null) {
      setState(() {
        _horarioController.text = horarioSeleccionado;
        this.horarioSeleccionado = horarioSeleccionado;
      });
      await _cargarAsientosOcupados();

      // Auto-seleccionar asiento desde el 5 en adelante según disponibilidad
      _autoSeleccionarAsiento();
    }
  }

  // Método para auto-seleccionar asiento disponible desde el 5 en adelante
  void _autoSeleccionarAsiento() {
    for (int i = 5; i <= 45; i++) {
      if (!asientosOcupados.contains(i)) {
        setState(() {
          asientoSeleccionado = i.toString().padLeft(2, '0');
          _asientoController.text = asientoSeleccionado!;
        });
        _asientoFocusNode.requestFocus();
        break;
      }
    }
  }

  // Método para mostrar selector de tarifa con navegación por teclado
  Future<void> _mostrarSelectorTarifa() async {
    if (tarifasDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay tarifas disponibles para este tipo de día'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isDomingoFeriado = tipoDia == 'DOMINGO / FERIADO';

    final tarifaSeleccionadaResult = await showDialog<Tarifa>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TarifaSelectorDialog(
        tarifas: tarifasDisponibles,
        tarifaSeleccionada: tarifaSeleccionada,
        isDomingoFeriado: isDomingoFeriado,
      ),
    );

    if (tarifaSeleccionadaResult != null) {
      setState(() {
        tarifaSeleccionada = tarifaSeleccionadaResult;
        valorBoleto = tarifaSeleccionadaResult.precio.toStringAsFixed(0);
        _valorController.text = valorBoleto;
      });

      // Después de seleccionar tarifa, mostrar confirmación de venta
      await _confirmarVenta();
    }
  }

  // MÉTODO ANTERIOR - COMENTADO PARA REFERENCIA
  /*
  Future<void> _mostrarSelectorHorariosAntiguo() async {
    await _horarioManager.cargarHorarios();

    String destinoReal = destino == 'Intermedio' ? origenIntermedio : destino;
    String categoria = tipoDia == 'DOMINGO / FERIADO' ? 'DomingosFeriados' :
                       (DateTime.now().weekday == 6 ? 'Sabados' : 'LunesViernes');

    List<String> horariosDisponibles = _horarioManager.obtenerHorariosCompletos(destinoReal, categoria);

    if (horariosDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay horarios configurados para este destino y tipo de día'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
  */

  // Mostrar diálogo de reloj digital para agregar horario (desde venta de pasajes)
  Future<String?> _mostrarDialogoRelojDigitalVenta(String destino, String categoria) async {
    int horaSeleccionada = 12;
    int minutoSeleccionado = 0;

    final isDomingoFeriado = categoria == 'DomingosFeriados';
    final colorPrimario = isDomingoFeriado ? Colors.red : Colors.blue;

    return await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 500,
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorPrimario.shade50,
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_alarm,
                          color: colorPrimario.shade700,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Agregar Salida Extra',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorPrimario.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Origen: ${destino == 'Aysen' ? 'Aysén' : 'Coyhaique'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      categoria == 'LunesViernes'
                          ? 'Lunes a Viernes'
                          : (categoria == 'Sabados' ? 'Sábado' : 'Domingo / Feriado'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                          SizedBox(width: 6),
                          Text(
                            'Solo válida para hoy',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),

                    // Reloj Digital
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorPrimario.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Selector de Hora
                          _buildDigitalTimePickerVenta(
                            value: horaSeleccionada,
                            maxValue: 23,
                            onChanged: (value) {
                              setStateDialog(() {
                                horaSeleccionada = value;
                              });
                            },
                            color: colorPrimario,
                          ),
                          // Separador ":"
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              ':',
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: colorPrimario.shade300,
                                height: 1.0,
                              ),
                            ),
                          ),
                          // Selector de Minuto
                          _buildDigitalTimePickerVenta(
                            value: minutoSeleccionado,
                            maxValue: 59,
                            step: 5,
                            onChanged: (value) {
                              setStateDialog(() {
                                minutoSeleccionado = value;
                              });
                            },
                            color: colorPrimario,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),

                    // Botones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'CANCELAR',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final horario = '${horaSeleccionada.toString().padLeft(2, '0')}:${minutoSeleccionado.toString().padLeft(2, '0')}';
                              Navigator.pop(context, horario);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorPrimario,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'AGREGAR',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Widget para construir el selector digital de tiempo (para venta)
  Widget _buildDigitalTimePickerVenta({
    required int value,
    required int maxValue,
    int step = 1,
    required ValueChanged<int> onChanged,
    required MaterialColor color,
  }) {
    return Column(
      children: [
        // Botón incrementar
        InkWell(
          onTap: () {
            int newValue = value + step;
            if (newValue > maxValue) newValue = 0;
            onChanged(newValue);
          },
          child: Container(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_drop_up,
              color: color.shade300,
              size: 40,
            ),
          ),
        ),
        // Valor actual
        Container(
          width: 100,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.shade700, width: 2),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: color.shade300,
              fontFeatures: [FontFeature.tabularFigures()],
              height: 1.0,
            ),
          ),
        ),
        // Botón decrementar
        InkWell(
          onTap: () {
            int newValue = value - step;
            if (newValue < 0) newValue = maxValue - (maxValue % step);
            onChanged(newValue);
          },
          child: Container(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_drop_down,
              color: color.shade300,
              size: 40,
            ),
          ),
        ),
      ],
    );
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

    // Validar que origen y destino no sean iguales (excepto para Intermedio)
    if (destino != 'Intermedio' && origenViaje == destino) {
      _mostrarError('El origen y destino no pueden ser iguales');
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
        origen: destino == 'Intermedio' ? origenIntermedio : origenViaje,
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
        // Obtener authProvider
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        String destinoFormateado = destino;
        String? origenParaTicket;

        if (destino == 'Intermedio' && kilometroIntermedio != null) {
          destinoFormateado = '$origenIntermedio - Intermedio Km $kilometroIntermedio';
          origenParaTicket = origenIntermedio;
        } else {
          // Para destinos regulares, usar el origen seleccionado
          origenParaTicket = origenViaje;
        }

        final comprobante = await BusTicketGenerator.generateAndPrintTicket(
          destino: destinoFormateado,
          horario: horarioSeleccionado!,
          asiento: asientoSeleccionado!,
          valor: valorBoleto,
          tipoDia: tipoDia,
          tituloTarifa: tarifaSeleccionada?.categoria ?? 'PUBLICO GENERAL',
          origen: origenParaTicket,
          kilometros: destino == 'Intermedio' ? kilometroIntermedio : null,
          metodoPago: paymentResult['metodo'],
          montoEfectivo: paymentResult['montoEfectivo'],
          montoTarjeta: paymentResult['montoTarjeta'],
          idSecretario: authProvider.idSecretario,
          origenSucursal: authProvider.sucursalActual,
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
              // Panel izquierdo - Mapa de asientos COMPLETO
              Expanded(
                flex: 2,
                child: Container(
                  color: _getColorSecundario(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Mapa de Asientos', isDomingoFeriado),
                      SizedBox(height: 12),

                      // Mapa de asientos con tamaño controlado
                      Expanded(
                        child: SingleChildScrollView(
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
                          _buildSectionTitle('CONFIGURACIÓN DEL VIAJE', isDomingoFeriado),
                          SizedBox(height: 16),

                          // ORIGEN DEL VIAJE - Púrpura pastel (se muestra primero)
                          if (destino != 'Intermedio') ...[
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.purple.shade200, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.trip_origin, color: Colors.purple.shade600, size: 24),
                                      SizedBox(width: 8),
                                      Text(
                                        'ORIGEN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  _buildSegmentedButtonColored(
                                    ['Coyhaique', 'Aysen'],
                                    origenViaje,
                                    (value) {
                                      setState(() {
                                        origenViaje = value;
                                        horarioSeleccionado = null;
                                      });
                                    },
                                    Colors.purple,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                          ],

                          // DESTINO DEL VIAJE - Turquesa pastel (se muestra segundo)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.shade200, width: 2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.location_on, color: Colors.teal.shade600, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      'DESTINO',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildSegmentedButtonColored(
                                  destinos,
                                  destino,
                                  (value) {
                                    setState(() {
                                      destino = value;
                                      if (value != 'Intermedio') kilometroIntermedio = null;

                                      // Ajustar origen automáticamente según destino
                                      if (value == 'Aysen') {
                                        origenViaje = 'Coyhaique';
                                      } else if (value == 'Coyhaique') {
                                        origenViaje = 'Aysen';
                                      }
                                    });
                                    _cargarTarifas();
                                  },
                                  Colors.teal,
                                ),
                              ],
                            ),
                          ),

                          // Origen para intermedio - Púrpura pastel
                          if (destino == 'Intermedio') ...[
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.purple.shade200, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.trip_origin, color: Colors.purple.shade600, size: 24),
                                      SizedBox(width: 8),
                                      Text(
                                        'ORIGEN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  _buildSegmentedButtonColored(
                                    ['Aysen', 'Coyhaique'],
                                    origenIntermedio,
                                    (value) {
                                      setState(() {
                                        origenIntermedio = value;
                                        horarioSeleccionado = null;
                                      });
                                    },
                                    Colors.purple,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Kilómetro intermedio',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
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
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
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
                          _buildSectionTitle('DATOS DEL BOLETO', isDomingoFeriado),
                          SizedBox(height: 16),

                          // CAMPO DE FECHA ESCRITA (050825 -> 05/08/25)
                          _buildLabel('Fecha'),
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
                            onFieldSubmitted: (_) async {
                              // Abrir automáticamente el selector de horarios
                              await _mostrarSelectorHorarios();
                            },
                          ),

                          SizedBox(height: 24),

                          // HORARIO (vertical) - Ahora usa selector de dropdown
                          _buildLabel('Horario de salida'),
                          InkWell(
                            onTap: _mostrarSelectorHorarios,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                hintText: 'Seleccione el horario',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                              child: Text(
                                _horarioController.text.isEmpty ? 'Seleccione el horario' : _horarioController.text,
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
                          _buildLabel('Número de asiento'),
                          TextFormField(
                            controller: _asientoController,
                            focusNode: _asientoFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: InputDecoration(
                              hintText: 'Ingrese el número de asiento (01-45)',
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
                            onFieldSubmitted: (_) async {
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              if (authProvider.isSecretaria) {
                                // Mostrar selector de tarifa para secretarias
                                await _mostrarSelectorTarifa();
                              } else {
                                // Para administradores, ir al campo de valor
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
                                    _buildLabel('Seleccionar tarifa'),
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
                                    _buildLabel('Valor del boleto'),
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
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _confirmarVenta,
                              icon: Icon(Icons.print, size: 24),
                              label: Text('GENERAR TICKET (F1)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getColorPrimario(),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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

    String origenTexto = destino == 'Intermedio' ? origenIntermedio : origenViaje;
    String destinoTexto = destino;

    if (destino == 'Intermedio' && kilometroIntermedio != null && kilometroIntermedio!.isNotEmpty) {
      destinoTexto = 'Int. Km $kilometroIntermedio';
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDomingoFeriado ? Colors.red.shade50 : Colors.blue.shade50,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDomingoFeriado ? Colors.red.shade300 : Colors.blue.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Título AppBar secundaria
          Text(
            'RESUMEN DEL VIAJE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),

          // Origen → Destino con colores
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trip_origin, size: 16, color: Colors.purple.shade700),
                    SizedBox(width: 4),
                    Text(
                      origenTexto,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: isDomingoFeriado ? Colors.red.shade600 : Colors.blue.shade600,
                  size: 20,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.teal.shade700),
                    SizedBox(width: 4),
                    Text(
                      destinoTexto,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Detalles: Asiento, Horario, Valor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoChip(
                asientoSeleccionado ?? '--',
                Icons.event_seat,
                isDomingoFeriado,
                label: 'Asiento',
              ),
              _buildInfoChip(
                horarioSeleccionado ?? '--:--',
                Icons.access_time,
                isDomingoFeriado,
                label: 'Horario',
              ),
              _buildInfoChip(
                '\$${valorBoleto != '0' ? valorBoleto : '--'}',
                Icons.attach_money,
                isDomingoFeriado,
                label: 'Valor',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, bool isDomingoFeriado, {String? label}) {
    return Column(
      children: [
        if (label != null) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
        ],
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDomingoFeriado ? Colors.red.shade100 : Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDomingoFeriado ? Colors.red.shade300 : Colors.blue.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isDomingoFeriado ? Colors.red.shade700 : Colors.blue.shade700,
              ),
              SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDomingoFeriado ? Colors.red.shade800 : Colors.blue.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildSegmentedButtonColored(
    List<String> options,
    String selected,
    Function(String) onSelect,
    MaterialColor baseColor,
  ) {
    return Container(
      height: 44,
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
                  color: isSelected ? baseColor.shade100 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? baseColor.shade700 : Colors.black87,
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
          _buildRow('Origen:', origen),
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