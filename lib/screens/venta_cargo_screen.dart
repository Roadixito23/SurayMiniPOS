import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cargo_ticket_generator.dart';
import '../widgets/numeric_input_field.dart';
import '../widgets/shared_widgets.dart';

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
  bool _isLoading = false;

  final FocusNode _articuloFocus = FocusNode();
  final FocusNode _valorFocus = FocusNode();
  final FocusNode _destinatarioFocus = FocusNode();
  final FocusNode _telDestFocus = FocusNode();
  final FocusNode _remitenteFocus = FocusNode();
  final FocusNode _telRemitFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    ServicesBinding.instance.addPostFrameCallback((_) {
      if (mounted) _articuloFocus.requestFocus();
    });
  }

  String? _validarValor(String? value) {
    if (value == null || value.isEmpty) return 'Ingrese un valor';
    int? valorNum = int.tryParse(value);
    if (valorNum == null || valorNum <= 0) return 'Valor debe ser mayor a 0';
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
    if (!_formKey.currentState!.validate()) return;

    if (remitenteController.text.isEmpty ||
        destinatarioController.text.isEmpty ||
        articuloController.text.isEmpty) {
      _mostrarError('Por favor complete todos los campos requeridos');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        remitente: remitenteController.text,
        destinatario: destinatarioController.text,
        destino: destino,
        articulo: articuloController.text,
        valor: valorController.text,
        telefonoDest: _formatTelefono(telefonoDestController.text),
        telefonoRemit: _formatTelefono(telefonoRemitController.text),
      ),
    );

    if (confirmar == true) {
      // Mostrar diálogo de método de pago
      final paymentResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => PaymentMethodDialog(
          totalAmount: double.parse(valorController.text),
        ),
      );

      if (paymentResult == null) return; // Usuario canceló el pago

      setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        await CargoTicketGenerator.generateAndPrintTicket(
          remitente: remitenteController.text,
          destinatario: destinatarioController.text,
          destino: destino,
          articulo: articuloController.text,
          valor: double.parse(valorController.text),
          telefonoDest: _formatTelefono(telefonoDestController.text),
          telefonoRemit: _formatTelefono(telefonoRemitController.text),
          metodoPago: paymentResult['metodo'],
          montoEfectivo: paymentResult['montoEfectivo'],
          montoTarjeta: paymentResult['montoTarjeta'],
          idSecretario: authProvider.idSecretario,
          origenSucursal: authProvider.sucursalActual,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket de carga generado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        _limpiarFormulario();
        _articuloFocus.requestFocus();
      } catch (e) {
        _mostrarError('Error al generar ticket: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _limpiarFormulario() {
    _formKey.currentState!.reset();
    remitenteController.clear();
    destinatarioController.clear();
    articuloController.clear();
    telefonoDestController.clear();
    telefonoRemitController.clear();
    valorController.clear();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
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
    _articuloFocus.dispose();
    _valorFocus.dispose();
    _destinatarioFocus.dispose();
    _telDestFocus.dispose();
    _remitenteFocus.dispose();
    _telRemitFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Venta de Carga / Encomiendas'),
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
              // Panel izquierdo - Datos del artículo
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.grey.shade100,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Datos del Artículo'),
                          SizedBox(height: 16),

                          // Destino
                          _buildLabel('Destino'),
                          _buildSegmentedButton(),

                          SizedBox(height: 24),

                          // Descripción del artículo
                          _buildLabel('Descripción del Artículo'),
                          TextFormField(
                            controller: articuloController,
                            focusNode: _articuloFocus,
                            decoration: InputDecoration(
                              hintText: 'Ej: Caja con herramientas',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingrese la descripción del artículo';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _valorFocus.requestFocus(),
                          ),

                          SizedBox(height: 24),

                          // Valor del artículo
                          _buildLabel('Valor Declarado del Artículo'),
                          TextFormField(
                            controller: valorController,
                            focusNode: _valorFocus,
                            decoration: InputDecoration(
                              hintText: 'Ingrese el valor',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: _validarValor,
                            onFieldSubmitted: (_) => _destinatarioFocus.requestFocus(),
                          ),

                          SizedBox(height: 24),

                          // Información adicional
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Se generarán 2 copias: una para el destinatario y otra para el remitente',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Panel derecho - Datos de personas
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Destinatario
                        _buildSectionTitle('Datos del Destinatario'),
                        SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Nombre Completo'),
                                  TextFormField(
                                    controller: destinatarioController,
                                    focusNode: _destinatarioFocus,
                                    decoration: InputDecoration(
                                      hintText: 'Nombre del destinatario',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Ingrese el nombre del destinatario';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (_) => _telDestFocus.requestFocus(),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Teléfono (Opcional)'),
                                  TextFormField(
                                    controller: telefonoDestController,
                                    focusNode: _telDestFocus,
                                    decoration: InputDecoration(
                                      hintText: '9XXXX XXXX',
                                      prefixIcon: Icon(Icons.phone, size: 20),
                                      prefixText: '+569 ',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(8),
                                    ],
                                    onFieldSubmitted: (_) => _remitenteFocus.requestFocus(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 32),
                        Divider(),
                        SizedBox(height: 16),

                        // Remitente
                        _buildSectionTitle('Datos del Remitente'),
                        SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Nombre Completo'),
                                  TextFormField(
                                    controller: remitenteController,
                                    focusNode: _remitenteFocus,
                                    decoration: InputDecoration(
                                      hintText: 'Nombre del remitente',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Ingrese el nombre del remitente';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (_) => _telRemitFocus.requestFocus(),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Teléfono (Opcional)'),
                                  TextFormField(
                                    controller: telefonoRemitController,
                                    focusNode: _telRemitFocus,
                                    decoration: InputDecoration(
                                      hintText: '9XXXX XXXX',
                                      prefixIcon: Icon(Icons.phone, size: 20),
                                      prefixText: '+569 ',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(8),
                                    ],
                                    onFieldSubmitted: (_) => confirmarVenta(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 32),

                        // Botón de generar
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : confirmarVenta,
                            icon: Icon(Icons.print),
                            label: Text(
                              'GENERAR TICKETS DE CARGA (F1)',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
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
                        Text(
                          'Generando tickets de carga...',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Por favor espere mientras se imprimen ambas copias',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
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

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildSegmentedButton() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: destinos.map((d) {
          bool isSelected = destino == d;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => destino = d),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.purple.shade100 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.purple.shade700 : Colors.black87,
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
  final String remitente, destinatario, destino, articulo, valor;
  final String telefonoDest, telefonoRemit;

  const _ConfirmDialog({
    required this.remitente,
    required this.destinatario,
    required this.destino,
    required this.articulo,
    required this.valor,
    required this.telefonoDest,
    required this.telefonoRemit,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.inventory_2, color: Colors.purple),
          SizedBox(width: 12),
          Text('Confirmar Envío de Carga'),
        ],
      ),
      content: Container(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              'Artículo',
              [
                _buildRow('Descripción:', articulo),
                _buildRow('Valor:', '\$$valor', bold: true),
                _buildRow('Destino:', destino),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoCard(
              'Destinatario',
              [
                _buildRow('Nombre:', destinatario),
                if (telefonoDest.isNotEmpty)
                  _buildRow('Teléfono:', '+569 $telefonoDest'),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoCard(
              'Remitente',
              [
                _buildRow('Nombre:', remitente),
                if (telefonoRemit.isNotEmpty)
                  _buildRow('Teléfono:', '+569 $telefonoRemit'),
              ],
            ),
          ],
        ),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}