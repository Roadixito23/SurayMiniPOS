import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/auth_provider.dart';
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

  String? origenSucursal; // Origen fijo basado en la sucursal seleccionada
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
      if (mounted) {
        // Obtener el origen de la sucursal seleccionada
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        setState(() {
          origenSucursal = authProvider.sucursalActual ?? 'Aysen';
          // Establecer destino como el opuesto al origen
          destino = origenSucursal == 'Aysen' ? 'Coyhaique' : 'Aysen';
        });
        _articuloFocus.requestFocus();
      }
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
      builder: (_) => _ModernConfirmDialog(
        remitente: remitenteController.text,
        destinatario: destinatarioController.text,
        origen: origenSucursal ?? 'Aysen',
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
        backgroundColor: Color(0xFFFFB3BA), // Coral pastel
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'ENTER: Siguiente Campo',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFB3BA), // Coral pastel
              Color(0xFFB3D9FF), // Azul cielo
            ],
          ),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // Panel izquierdo - Datos del artículo
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(
                              'Datos del Artículo',
                              Icons.inventory_2,
                              Color(0xFFFF8A80),
                            ),
                            SizedBox(height: 16),

                            // Origen (solo lectura)
                            _buildLabel('Origen', Icons.flight_takeoff),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFF90CAF9), width: 2),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.location_city, color: Color(0xFF1976D2)),
                                  SizedBox(width: 12),
                                  Text(
                                    origenSucursal ?? 'Cargando...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1976D2),
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(Icons.lock, color: Colors.grey, size: 16),
                                ],
                              ),
                            ),

                            SizedBox(height: 24),

                            // Destino
                            _buildLabel('Destino', Icons.flight_land),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFFFFB74D), width: 2),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.place, color: Color(0xFFFF6F00)),
                                  SizedBox(width: 12),
                                  Text(
                                    destino,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF6F00),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 24),

                            // Descripción del artículo
                            _buildLabel('Descripción del Artículo', Icons.description),
                            TextFormField(
                              controller: articuloController,
                              focusNode: _articuloFocus,
                              decoration: InputDecoration(
                                hintText: 'Ej: Caja con herramientas',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFFFFB3BA), width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFFFF8A80), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.all(16),
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
                            _buildLabel('Valor Declarado', Icons.attach_money),
                            TextFormField(
                              controller: valorController,
                              focusNode: _valorFocus,
                              decoration: InputDecoration(
                                hintText: 'Ingrese el valor',
                                prefixText: '\$ ',
                                prefixStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 18,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFFB3D9FF), width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF64B5F6), width: 2),
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
                                gradient: LinearGradient(
                                  colors: [Color(0xFFE1F5FE), Color(0xFFFFF9C4)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Color(0xFF81D4FA), width: 2),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info, color: Color(0xFF0277BD), size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Se generarán 2 copias:\nDestinatario y Remitente',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF01579B),
                                        fontWeight: FontWeight.w500,
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
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Destinatario
                          _buildSectionTitle(
                            'Datos del Destinatario',
                            Icons.person_pin_circle,
                            Color(0xFF64B5F6),
                          ),
                          SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Nombre Completo', Icons.person),
                                    TextFormField(
                                      controller: destinatarioController,
                                      focusNode: _destinatarioFocus,
                                      decoration: _buildInputDecoration('Nombre del destinatario'),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingrese el nombre';
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
                                    _buildLabel('Teléfono (Opcional)', Icons.phone),
                                    TextFormField(
                                      controller: telefonoDestController,
                                      focusNode: _telDestFocus,
                                      decoration: InputDecoration(
                                        hintText: 'XXXX XXXX',
                                        prefixIcon: Icon(Icons.phone_android, size: 20),
                                        prefixText: '+569 ',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Color(0xFF64B5F6), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
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
                          Divider(thickness: 2, color: Color(0xFFFFB3BA)),
                          SizedBox(height: 16),

                          // Remitente
                          _buildSectionTitle(
                            'Datos del Remitente',
                            Icons.person_outline,
                            Color(0xFFFFB3BA),
                          ),
                          SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Nombre Completo', Icons.person),
                                    TextFormField(
                                      controller: remitenteController,
                                      focusNode: _remitenteFocus,
                                      decoration: _buildInputDecoration('Nombre del remitente'),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingrese el nombre';
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
                                    _buildLabel('Teléfono (Opcional)', Icons.phone),
                                    TextFormField(
                                      controller: telefonoRemitController,
                                      focusNode: _telRemitFocus,
                                      decoration: InputDecoration(
                                        hintText: 'XXXX XXXX',
                                        prefixIcon: Icon(Icons.phone_android, size: 20),
                                        prefixText: '+569 ',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Color(0xFFFFB3BA), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
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
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF8A80), Color(0xFFFF80AB)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFFF8A80).withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : confirmarVenta,
                              icon: Icon(Icons.print, size: 24),
                              label: Text(
                                'GENERAR VENTA DE CARGA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                minimumSize: Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
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
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A80)),
                          ),
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
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFFFF8A80), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

// Dialog moderno con diseño mejorado
class _ModernConfirmDialog extends StatelessWidget {
  final String remitente, destinatario, origen, destino, articulo, valor;
  final String telefonoDest, telefonoRemit;

  const _ModernConfirmDialog({
    required this.remitente,
    required this.destinatario,
    required this.origen,
    required this.destino,
    required this.articulo,
    required this.valor,
    required this.telefonoDest,
    required this.telefonoRemit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE4E1),
              Color(0xFFE3F2FD),
            ],
          ),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8A80), Color(0xFFFF80AB)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF8A80).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Text(
                    'Confirmar Envío de Carga',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Ruta con flechas
            _buildRutaCard(),

            SizedBox(height: 16),

            // Información del artículo
            _buildInfoCard(
              'Artículo',
              Icons.inventory_2,
              Color(0xFFFFB3BA),
              [
                _buildInfoRow('Descripción', articulo),
                _buildInfoRow('Valor', '\$$valor', bold: true),
              ],
            ),

            SizedBox(height: 12),

            // Información del destinatario
            _buildInfoCard(
              'Destinatario',
              Icons.person_pin,
              Color(0xFF64B5F6),
              [
                _buildInfoRow('Nombre', destinatario),
                if (telefonoDest.isNotEmpty)
                  _buildInfoRow('Teléfono', '+569 $telefonoDest'),
              ],
            ),

            SizedBox(height: 12),

            // Información del remitente
            _buildInfoCard(
              'Remitente',
              Icons.person,
              Color(0xFFFFB3BA),
              [
                _buildInfoRow('Nombre', remitente),
                if (telefonoRemit.isNotEmpty)
                  _buildInfoRow('Teléfono', '+569 $telefonoRemit'),
              ],
            ),

            SizedBox(height: 24),

            // Botones
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'CANCELAR',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF66BB6A), Color(0xFF81C784)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF66BB6A).withOpacity(0.5),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: Icon(Icons.check_circle, size: 24),
                      label: Text(
                        'CONFIRMAR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
  }

  Widget _buildRutaCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLocationBadge(origen, Colors.blue, Icons.flight_takeoff),
          Icon(Icons.arrow_forward, size: 40, color: Color(0xFFFF8A80)),
          _buildLocationBadge(destino, Colors.orange, Icons.flight_land),
        ],
      ),
    );
  }

  Widget _buildLocationBadge(String location, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        SizedBox(height: 8),
        Text(
          location,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
