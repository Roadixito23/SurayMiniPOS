import 'package:flutter/material.dart';
import 'bus_ticket_generator.dart';
import 'numeric_input_field.dart';
import 'horario_input_field.dart';

class VentaBusScreen extends StatefulWidget {
  @override
  _VentaBusScreenState createState() => _VentaBusScreenState();
}

class _VentaBusScreenState extends State<VentaBusScreen> {
  String destino = 'Aysen';
  final List<String> destinos = ['Aysen', 'Intermedio', 'Coyhaique'];
  String? kilometroIntermedio;
  String origenIntermedio = 'Aysen'; // Valor predeterminado para origen en caso intermedio

  String? horarioSeleccionado;
  String? asientoSeleccionado;
  String valorBoleto = '0';
  bool _isLoading = false; // Estado para controlar la carga

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controlador de desplazamiento
  final ScrollController _scrollController = ScrollController();

  // Keys para cada campo de entrada
  final GlobalKey _horarioKey = GlobalKey();
  final GlobalKey _asientoKey = GlobalKey();
  final GlobalKey _valorKey = GlobalKey();
  final GlobalKey _kmIntermedioKey = GlobalKey();

  // Focus nodes para cada campo de entrada
  final FocusNode _horarioFocusNode = FocusNode();
  final FocusNode _asientoFocusNode = FocusNode();
  final FocusNode _valorFocusNode = FocusNode();
  final FocusNode _kmIntermedioFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  // Método para desplazar y alinear el widget con la AppBar
  void _scrollToWidget(GlobalKey key) {
    Future.delayed(Duration(milliseconds: 100), () {
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          alignment: 0.0, // 0.0 = alineado con la parte superior (AppBar)
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _horarioFocusNode.dispose();
    _asientoFocusNode.dispose();
    _valorFocusNode.dispose();
    _kmIntermedioFocusNode.dispose();
    super.dispose();
  }

  // Función para validar formato de hora
  String? _validarHorario(String value) {
    if (value.isEmpty) {
      return 'Ingrese un horario';
    }

    // Verificar formato HH:MM
    RegExp regExp = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (!regExp.hasMatch(value)) {
      return 'Formato inválido (HH:MM)';
    }

    return null;
  }

  // Función para validar asiento
  String? _validarAsiento(String value) {
    if (value.isEmpty) {
      return 'Ingrese un asiento';
    }

    int? asiento = int.tryParse(value);
    if (asiento == null || asiento < 0 || asiento > 45) {
      return 'Asiento inválido (1-45)';
    }

    return null;
  }

  // Función para validar valor
  String? _validarValor(String value) {
    if (value.isEmpty) {
      return 'Ingrese un valor';
    }

    int? valor = int.tryParse(value);
    if (valor == null || valor <= 0) {
      return 'Valor debe ser mayor a 0';
    }

    return null;
  }

  void _confirmarVenta() async {
    // Validar formulario
    if (_formKey.currentState!.validate()) {
      if (horarioSeleccionado == null || asientoSeleccionado == null || int.parse(valorBoleto) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Por favor complete todos los campos correctamente'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      // Validar km intermedio si es necesario
      if (destino == 'Intermedio' && (kilometroIntermedio == null || kilometroIntermedio!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Por favor ingrese el kilómetro intermedio'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Confirmar Venta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (destino == 'Intermedio')
                Text('Origen: $origenIntermedio'),
              Text(destino == 'Intermedio'
                  ? 'Destino: $destino (Km ${kilometroIntermedio ?? "no especificado"})'
                  : 'Destino: $destino'),
              Text('Salida: $horarioSeleccionado'),
              Text('Asiento: $asientoSeleccionado'),
              Text('Valor: \$${valorBoleto}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Confirmar'),
            ),
          ],
        ),
      );

      if (confirmar == true) {
        // Mostrar indicador de carga
        setState(() {
          _isLoading = true;
        });

        try {
          // Generar el ticket en un bloque try-catch
          // Construir el destino con formato adecuado para intermedios
          String destinoFormateado = destino;
          if (destino == 'Intermedio' && kilometroIntermedio != null) {
            destinoFormateado = '$origenIntermedio - Intermedio Km ${kilometroIntermedio}';
          }

          await BusTicketGenerator.generateAndPrintTicket(
            destino: destinoFormateado,
            horario: horarioSeleccionado!,
            asiento: asientoSeleccionado!,
            valor: valorBoleto,
          );

          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ticket generado exitosamente'),
            backgroundColor: Colors.green,
          ));

          // Limpiar todos los campos después de generar el ticket
          setState(() {
            horarioSeleccionado = null;
            asientoSeleccionado = null;
            valorBoleto = '0';
          });

          // Volver a enfocar el primer campo (horario)
          Future.delayed(Duration(milliseconds: 500), () {
            _horarioFocusNode.requestFocus();
            _scrollToWidget(_horarioKey);
          });
        } catch (e) {
          // Mostrar mensaje de error
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al generar el ticket: $e'),
            backgroundColor: Colors.red,
          ));
        } finally {
          // Ocultar indicador de carga
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text('Venta de Boletos'),
            centerTitle: true,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Agregamos un espacio en la parte superior para que el primer elemento no quede
                  // justo debajo de la AppBar
                  SizedBox(height: 16.0),

                  // Selector de destino
                  Text(
                    'Destino',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: destinos.map((d) {
                        bool isSelected = destino == d;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              destino = d;
                              // Resetear el kilómetro intermedio si se selecciona otro destino
                              if (d != 'Intermedio') {
                                kilometroIntermedio = null;
                              }
                            }),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                d,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.blue.shade700 : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Selector de origen para destino Intermedio
                  if (destino == 'Intermedio') ...[
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Origen del Viaje',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Seleccione desde dónde parte el bus:',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: ['Aysen', 'Coyhaique'].map((origen) {
                              bool isSelected = origenIntermedio == origen;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      origenIntermedio = origen;
                                      // Al cambiar origen, resetear el horario seleccionado
                                      horarioSeleccionado = null;
                                    }),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.blue.shade200 : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        origen,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? Colors.blue.shade700 : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Campo para kilómetro intermedio (solo visible cuando destino es "Intermedio")
                  if (destino == 'Intermedio') ...[
                    SizedBox(height: 16),
                    Container(
                      key: _kmIntermedioKey,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kilómetro Intermedio',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ingrese el kilómetro del punto intermedio (máximo 64 km)',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 12),
                          NumericInputField(
                            value: kilometroIntermedio,
                            hintText: 'Ej: 20',
                            focusNode: _kmIntermedioFocusNode,
                            validator: (value) {
                              if (value.isEmpty) {
                                return 'Ingrese el N° kilómetro';
                              }
                              int? km = int.tryParse(value);
                              if (km == null) {
                                return 'Ingrese un número válido';
                              }
                              if (km <= 0 || km > 64) {
                                return 'El kilómetro debe estar entre 1 y 64';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                // Limitar a 2 dígitos como máximo
                                if (value.length <= 2 && int.tryParse(value) != null) {
                                  // Solo actualizar si el valor es <= 64
                                  int km = int.parse(value);
                                  if (km <= 64) {
                                    kilometroIntermedio = value;
                                  }
                                }
                              });
                            },
                            onEnterPressed: () {
                              // Al presionar Enter, seguir al siguiente campo
                              _horarioFocusNode.requestFocus();
                              _scrollToWidget(_horarioKey);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  // Campo de horario con sugerencias horizontales
                  Container(
                    key: _horarioKey,
                    padding: EdgeInsets.only(top: 8.0),
                    child: HorarioInputField(
                      value: horarioSeleccionado,
                      destino: destino,
                      origenIntermedio: origenIntermedio, // Pasamos el origen intermedio
                      validator: _validarHorario,
                      focusNode: _horarioFocusNode,
                      onChanged: (value) {
                        setState(() {
                          horarioSeleccionado = value;
                        });
                      },
                      onEnterPressed: () {
                        // Pasar al siguiente campo
                        _asientoFocusNode.requestFocus();
                        // Hacer scroll para alinear con la AppBar
                        _scrollToWidget(_asientoKey);
                      },
                    ),
                  ),

                  SizedBox(height: 24),

                  // Campo de asiento con teclado numérico
                  Container(
                    key: _asientoKey,
                    padding: EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Número de Asiento',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        SizedBox(height: 8.0),
                        NumericInputField(
                          label: '',
                          value: asientoSeleccionado,
                          hintText: '01-45',
                          validator: _validarAsiento,
                          focusNode: _asientoFocusNode,
                          onChanged: (value) {
                            setState(() {
                              asientoSeleccionado = value;
                            });
                          },
                          onEnterPressed: () {
                            // Pasar al siguiente campo
                            _valorFocusNode.requestFocus();
                            // Hacer scroll para alinear con la AppBar
                            _scrollToWidget(_valorKey);
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Campo de valor con teclado numérico
                  Container(
                    key: _valorKey,
                    padding: EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valor del Boleto',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        SizedBox(height: 8.0),
                        NumericInputField(
                          label: '',
                          value: valorBoleto == '0' ? '' : valorBoleto,
                          hintText: 'Ingrese valor',
                          prefix: '\$',
                          validator: _validarValor,
                          focusNode: _valorFocusNode,
                          onChanged: (value) {
                            setState(() {
                              valorBoleto = value;
                            });
                          },
                          onEnterPressed: () {
                            // Este es el último campo, así que generamos el ticket
                            _confirmarVenta();
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 36),

                  // Botón de generar ticket
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _confirmarVenta,
                      child: Text(
                        'GENERAR TICKET',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Overlay de carga
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Generando ticket...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Por favor espere',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}