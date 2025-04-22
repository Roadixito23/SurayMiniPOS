import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'bus_ticket_generator.dart';
import 'package:flutter/services.dart';

class VentaBusScreen extends StatefulWidget {
  @override
  _VentaBusScreenState createState() => _VentaBusScreenState();
}

class _VentaBusScreenState extends State<VentaBusScreen> {
  // Valores por defecto
  bool destinoAysen = true; // true para Aysen, false para Coyhaique
  String asientoSeleccionado = "No seleccionado";
  String horarioSeleccionado = "No seleccionado";
  TextEditingController asientoController = TextEditingController();
  TextEditingController horarioManualController = TextEditingController();
  TextEditingController valorBoletoController = TextEditingController(text: "0");

  // Focus nodes para manejar la navegación entre campos
  final FocusNode asientoFocusNode = FocusNode();
  final FocusNode horarioFocusNode = FocusNode();
  final FocusNode valorFocusNode = FocusNode();

  bool mostrarDetallesBoleto = false;
  bool mostrarSelectorHorario = false;
  bool isLoadingHorarios = true;

  // Lista de horarios
  List<Map<String, String>> horarios = [];

  @override
  void initState() {
    super.initState();
    // Cargar horarios guardados al inicializar
    cargarHorariosGuardados();

    // Actualizar asientoSeleccionado cuando cambie el valor del controlador
    asientoController.addListener(() {
      setState(() {
        if (asientoController.text.isNotEmpty) {
          asientoSeleccionado = asientoController.text;
        } else {
          asientoSeleccionado = "No seleccionado";
        }
      });
    });
  }

  @override
  void dispose() {
    asientoController.dispose();
    horarioManualController.dispose();
    valorBoletoController.dispose();
    asientoFocusNode.dispose();
    horarioFocusNode.dispose();
    valorFocusNode.dispose();
    super.dispose();
  }

  // Método para formatear horario
  void _formatearHorarioManual() {
    String texto = horarioManualController.text;

    // Si solo contiene dígitos y tiene 3 o 4 caracteres, insertamos el separador ":"
    if (RegExp(r'^\d+$').hasMatch(texto)) {
      // Formatear números como 730 a 7:30
      if (texto.length == 3) {
        texto = "${texto.substring(0, 1)}:${texto.substring(1)}";
        horarioManualController.value = TextEditingValue(
            text: texto,
            selection: TextSelection.collapsed(offset: texto.length)
        );
      }
      // Formatear números como 1430 a 14:30
      else if (texto.length == 4) {
        texto = "${texto.substring(0, 2)}:${texto.substring(2)}";
        horarioManualController.value = TextEditingValue(
            text: texto,
            selection: TextSelection.collapsed(offset: texto.length)
        );
      }
    }

    setState(() {
      horarioSeleccionado = texto;
    });
  }

  // Método para validar el formato de hora
  bool _validarFormatoHora(String hora) {
    if (hora.isEmpty) return false;

    // Primero intenta formatear si es posible
    if (RegExp(r'^\d{3,4}$').hasMatch(hora)) {
      return true; // Permitir formatos como "730" o "1430"
    }

    // Verificar si tiene el formato H:MM o HH:MM
    final RegExp regExp = RegExp(r'^([0-9]|[0-1][0-9]|2[0-3]):([0-5][0-9])$');
    return regExp.hasMatch(hora);
  }

  // Método para obtener la ruta del archivo local
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Método para obtener el archivo local
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/horarios.json');
  }

  // Método para cargar horarios desde el archivo local
  Future<void> cargarHorariosGuardados() async {
    setState(() {
      isLoadingHorarios = true;
    });

    try {
      final file = await _localFile;

      // Verificar si el archivo existe
      if (await file.exists()) {
        String contents = await file.readAsString();
        List<dynamic> data = jsonDecode(contents);

        // Convertir los datos JSON a la lista de horarios
        List<Map<String, String>> horariosTemp = [];
        for (var item in data) {
          horariosTemp.add({
            'hora': item['hora'] ?? '',
            'destino': item['destino'] ?? '',
          });
        }

        setState(() {
          horarios = horariosTemp;
          isLoadingHorarios = false;
        });
      } else {
        // Si el archivo no existe, inicializar con algunos valores predeterminados
        setState(() {
          horarios = [
            {'hora': '8:00', 'destino': 'Aysen'},
            {'hora': '10:30', 'destino': 'Coyhaique'},
            {'hora': '13:45', 'destino': 'Aysen'},
            {'hora': '15:30', 'destino': 'Coyhaique'},
            {'hora': '18:00', 'destino': 'Aysen'},
          ];
          isLoadingHorarios = false;
        });
      }
    } catch (e) {
      // En caso de error, inicializar con valores predeterminados
      setState(() {
        horarios = [
          {'hora': '8:00', 'destino': 'Aysen'},
          {'hora': '10:30', 'destino': 'Coyhaique'},
          {'hora': '13:45', 'destino': 'Aysen'},
          {'hora': '15:30', 'destino': 'Coyhaique'},
          {'hora': '18:00', 'destino': 'Aysen'},
        ];
        isLoadingHorarios = false;
      });

      // Mostrar mensaje de error si es necesario
      print('Error al cargar horarios: $e');
    }
  }

  // Método para continuar al siguiente paso
  void _handleContinue() {
    // Formatear el horario antes de validar
    _formatearHorarioManual();

    if (asientoSeleccionado == "No seleccionado" ||
        horarioSeleccionado == "No seleccionado" ||
        !_validarFormatoHora(horarioSeleccionado) ||
        valorBoletoController.text.isEmpty) {
      // Mostrar error si faltan datos o el formato de hora es incorrecto
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!_validarFormatoHora(horarioSeleccionado) && horarioSeleccionado != "No seleccionado"
              ? 'El formato del horario debe ser H:MM o HH:MM (ej: 7:30)'
              : 'Por favor, complete todos los campos'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // Mostrar vista de detalles
      setState(() {
        mostrarDetallesBoleto = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generar Venta Bus'),
        centerTitle: true,
      ),
      body: isLoadingHorarios
          ? Center(child: CircularProgressIndicator())
          : (mostrarDetallesBoleto ? _construirVistaDetallesBoleto() : _construirFormularioVenta()),
    );
  }

  // Vista del formulario principal para generar venta
  Widget _construirFormularioVenta() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de destino (Switch)
          Card(
            elevation: 4.0,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccionar Destino',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 15.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        destinoAysen ? 'Destino: Aysen' : 'Destino: Coyhaique',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Switch(
                        value: destinoAysen,
                        activeColor: Colors.blue,
                        onChanged: (value) {
                          setState(() {
                            destinoAysen = value;
                            // Restablecer el horario seleccionado al cambiar el destino
                            horarioSeleccionado = "No seleccionado";
                            horarioManualController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Coyhaique', style: TextStyle(color: !destinoAysen ? Colors.blue : Colors.grey)),
                      Text('Aysen', style: TextStyle(color: destinoAysen ? Colors.blue : Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.0),

          // Selector de asiento
          Card(
            elevation: 4.0,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Número de Asiento',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 15.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: asientoController,
                          focusNode: asientoFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Ingrese número de asiento',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.event_seat),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) {
                            // Al presionar Enter, pasar al campo de horario
                            FocusScope.of(context).requestFocus(horarioFocusNode);
                          },
                        ),
                      ),
                      SizedBox(width: 10.0),
                      ElevatedButton(
                        onPressed: () {
                          // Muestra un diálogo para seleccionar asiento
                          _mostrarDialogoSeleccionAsiento();
                        },
                        child: Text('Asiento'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ],
                  ),
                  if (asientoSeleccionado != "No seleccionado")
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Asiento seleccionado: $asientoSeleccionado',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.0),

          // Selector de horario
          mostrarSelectorHorario
              ? _construirSelectorHorario()
              : Card(
            elevation: 4.0,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Horario',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 15.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: horarioManualController,
                          focusNode: horarioFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Ingrese horario (HH:MM)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time),
                            hintText: 'Ej: 7:30 o 730',
                            helperText: 'Presione Enter para formatear',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            setState(() {
                              horarioSeleccionado = value;
                            });
                          },
                          onSubmitted: (_) {
                            // Al presionar Enter, formatear el horario y pasar al campo de valor
                            _formatearHorarioManual();
                            FocusScope.of(context).requestFocus(valorFocusNode);
                          },
                        ),
                      ),
                      SizedBox(width: 10.0),
                      ElevatedButton.icon(
                        icon: Icon(Icons.format_list_numbered),
                        label: Text('Lista'),
                        onPressed: () {
                          setState(() {
                            mostrarSelectorHorario = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                        ),
                      ),
                    ],
                  ),
                  if (horarioSeleccionado != "No seleccionado")
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Horario seleccionado: $horarioSeleccionado',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.0),

          // Valor del boleto
          Card(
            elevation: 4.0,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Valor del Boleto',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 15.0),
                  TextField(
                    controller: valorBoletoController,
                    focusNode: valorFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Valor (\$)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      // Al presionar Enter en el campo de valor, continuar con el proceso
                      _handleContinue();
                    },
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 30.0),

          // Botón para continuar
          Center(
            child: ElevatedButton(
              onPressed: _handleContinue,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                backgroundColor: Colors.blue,
                minimumSize: Size(200, 50),
              ),
              child: Text(
                'Siguiente',
                style: TextStyle(fontSize: 18.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar el selector de horarios
  Widget _construirSelectorHorario() {
    // Filtrar horarios según el destino seleccionado
    String destinoFiltrado = destinoAysen ? 'Aysen' : 'Coyhaique';
    List<Map<String, String>> horariosFiltrados = horarios
        .where((horario) => horario['destino'] == destinoFiltrado)
        .toList();

    // Ordenar horarios por hora
    horariosFiltrados.sort((a, b) => a['hora']!.compareTo(b['hora']!));

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seleccionar Horario',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      mostrarSelectorHorario = false;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 10.0),
            horariosFiltrados.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No hay horarios disponibles para $destinoFiltrado',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
                : Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: horariosFiltrados.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(Icons.access_time, color: Colors.blue),
                    title: Text(
                      horariosFiltrados[index]['hora']!,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    tileColor: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                    onTap: () {
                      setState(() {
                        horarioSeleccionado = horariosFiltrados[index]['hora']!;
                        horarioManualController.text = horarioSeleccionado;
                        mostrarSelectorHorario = false;
                      });
                      // Mover el foco al campo de valor después de seleccionar un horario
                      FocusScope.of(context).requestFocus(valorFocusNode);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 10.0),
            Divider(),
            SizedBox(height: 10.0),
            Text(
              'Ingresar manualmente:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10.0),
            TextField(
              controller: horarioManualController,
              decoration: InputDecoration(
                labelText: 'Horario',
                border: OutlineInputBorder(),
                hintText: 'Ej: 7:30 o 730',
                helperText: 'Presione Enter para confirmar',
                suffixIcon: IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () {
                    _formatearHorarioManual();
                    if (_validarFormatoHora(horarioManualController.text)) {
                      setState(() {
                        mostrarSelectorHorario = false;
                      });
                      // Mover el foco al campo de valor
                      FocusScope.of(context).requestFocus(valorFocusNode);
                    } else {
                      // Mostrar error si el formato es incorrecto
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Formato incorrecto. Escriba como 7:30 o 730'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (value) {
                setState(() {
                  horarioSeleccionado = value;
                });
              },
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                _formatearHorarioManual();
                if (_validarFormatoHora(horarioManualController.text)) {
                  setState(() {
                    mostrarSelectorHorario = false;
                  });
                  // Mover el foco al campo de valor
                  FocusScope.of(context).requestFocus(valorFocusNode);
                }
              },
            ),
            SizedBox(height: 15.0),
            Center(
              child: TextButton.icon(
                icon: Icon(Icons.refresh),
                label: Text('Recargar Horarios'),
                onPressed: () {
                  // Recargar los horarios guardados
                  cargarHorariosGuardados();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Diálogo para seleccionar asiento
  void _mostrarDialogoSeleccionAsiento() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleccionar Asiento'),
          content: Container(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 16,
              itemBuilder: (context, index) {
                final asientoNum = index + 1;
                return ElevatedButton(
                  child: Text('$asientoNum'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: () {
                    setState(() {
                      // No formatear con ceros iniciales
                      asientoSeleccionado = asientoNum.toString();
                      asientoController.text = asientoSeleccionado;
                    });
                    Navigator.of(context).pop();
                    // Mover el foco al campo de horario después de seleccionar un asiento
                    FocusScope.of(context).requestFocus(horarioFocusNode);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Vista de detalles del boleto
  Widget _construirVistaDetallesBoleto() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Detalles del Boleto',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          SizedBox(height: 20.0),
          // Tarjeta simulando boleto
          Card(
            elevation: 8.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
              side: BorderSide(color: Colors.blue.shade200, width: 2),
            ),
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'BOLETO DE VIAJE',
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 5.0),
                  Center(
                    child: Text(
                      'Transportes XYZ',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Divider(thickness: 2),
                  SizedBox(height: 15.0),
                  _buildBoletoRow('Destino:', destinoAysen ? 'Aysen' : 'Coyhaique'),
                  _buildBoletoRow('Fecha:', DateTime.now().toString().substring(0, 10)),
                  _buildBoletoRow('Hora:', horarioSeleccionado),
                  _buildBoletoRow('Asiento:', asientoSeleccionado),
                  Divider(),
                  _buildBoletoRow('Valor:', '\$${valorBoletoController.text}'),
                  SizedBox(height: 10.0),
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      child: Text(
                        'N° 00012345',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30.0),
          // Botones de acción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    mostrarDetallesBoleto = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: Colors.grey,
                ),
                child: Text('Volver'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Llamar al generador de tickets con los parámetros actualizados
                    await BusTicketGenerator.generateAndPrintTicket(
                      destino: destinoAysen ? 'Aysen' : 'Coyhaique',
                      asiento: asientoSeleccionado,
                      horario: horarioSeleccionado,
                      valor: valorBoletoController.text,
                    );

                    // Mostrar mensaje de éxito
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Boleto impreso con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Opcional: volver a la pantalla principal después de imprimir
                    Future.delayed(Duration(seconds: 2), () {
                      Navigator.pop(context);
                    });
                  } catch (e) {
                    // Mostrar error si algo falla
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al imprimir: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: Colors.green,
                ),
                child: Text('Imprimir Boleto'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para filas del boleto
  Widget _buildBoletoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.0,
            ),
          ),
        ],
      ),
    );
  }
}