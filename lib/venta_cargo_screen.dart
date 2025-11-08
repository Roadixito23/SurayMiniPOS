import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cargo_ticket_generator.dart';
import 'numeric_input_field.dart';
import 'shared_widgets.dart';
import 'responsive_helper.dart';

class VentaCargoScreen extends StatefulWidget {
  @override
  _VentaCargoScreenState createState() => _VentaCargoScreenState();
}

class _VentaCargoScreenState extends State<VentaCargoScreen> {
  final TextEditingController remitenteController = TextEditingController();
  final TextEditingController destinatarioController = TextEditingController();
  final TextEditingController articuloController = TextEditingController();
  final TextEditingController telefonoDestController = TextEditingController();
  final TextEditingController telefonoRemitController = TextEditingController();
  final TextEditingController valorController = TextEditingController();

  String destino = 'Aysen';
  final List<String> destinos = ['Aysen', 'Coyhaique'];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  String? _validarValor(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese un valor';
    }
    int? valorNum = int.tryParse(value);
    if (valorNum == null || valorNum <= 0) {
      return 'Valor debe ser mayor a 0';
    }
    return null;
  }

  String _formatTelefono(String telefono) {
    if (telefono.isEmpty) return '';
    if (telefono.length == 8) {
      return '9${telefono.substring(0, 4)} ${telefono.substring(4)}';
    }
    return telefono;
  }

  void confirmarVenta() async {
    if (_formKey.currentState!.validate()) {
      if (remitenteController.text.isEmpty ||
          destinatarioController.text.isEmpty ||
          articuloController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Por favor complete todos los campos requeridos')),
        );
        return;
      }

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => ConfirmationDialog(
          title: 'Confirmar Envío de Carga',
          content: "Remitente: ${remitenteController.text}\n"
              "Destinatario: ${destinatarioController.text}\n"
              "Destino: $destino\n"
              "Artículo: ${articuloController.text}\n"
              "Valor: \$${valorController.text}",
        ),
      );

      if (confirmar == true) {
        setState(() {
          _isLoading = true;
        });

        try {
          await CargoTicketGenerator.generateAndPrintTicket(
            remitente: remitenteController.text,
            destinatario: destinatarioController.text,
            destino: destino,
            articulo: articuloController.text,
            valor: double.parse(valorController.text),
            telefonoDest: _formatTelefono(telefonoDestController.text),
            telefonoRemit: _formatTelefono(telefonoRemitController.text),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ticket de carga generado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );

          _formKey.currentState!.reset();
          remitenteController.clear();
          destinatarioController.clear();
          articuloController.clear();
          telefonoDestController.clear();
          telefonoRemitController.clear();
          valorController.clear();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al generar ticket: $e'),
              backgroundColor: Colors.red,
            ),
          );
        } finally {
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
            title: Text('Venta de Carga'),
            centerTitle: true,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  SizedBox(height: 20),

                  Text(
                    'Datos del Artículo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: articuloController,
                    decoration: InputDecoration(
                      labelText: 'Descripción del Artículo',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese la descripción del artículo';
                      }
                      return null;
                    },
                    maxLines: 2,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: valorController,
                    decoration: InputDecoration(
                      labelText: 'Valor del Artículo',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: _validarValor,
                  ),
                  SizedBox(height: 20),

                  Text(
                    'Datos del Destinatario',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: destinatarioController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del Destinatario',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese el nombre del destinatario';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: telefonoDestController,
                    decoration: InputDecoration(
                      labelText: 'Teléfono Destinatario (Opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      prefixText: '+569 ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                  ),
                  SizedBox(height: 20),

                  Text(
                    'Datos del Remitente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: remitenteController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del Remitente',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese el nombre del remitente';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: telefonoRemitController,
                    decoration: InputDecoration(
                      labelText: 'Teléfono Remitente (Opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      prefixText: '+569 ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : confirmarVenta,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: Colors.blue.shade700,
                    ),
                    child: Text(
                      'Generar Ticket de Carga',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

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
                        'Generando tickets de carga...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Por favor espere mientras se imprimen ambas copias',
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

  @override
  void dispose() {
    remitenteController.dispose();
    destinatarioController.dispose();
    articuloController.dispose();
    telefonoDestController.dispose();
    telefonoRemitController.dispose();
    valorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
