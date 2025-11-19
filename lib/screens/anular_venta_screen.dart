import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../database/caja_database.dart';
import '../models/auth_provider.dart';

class AnularVentaScreen extends StatefulWidget {
  @override
  _AnularVentaScreenState createState() => _AnularVentaScreenState();
}

class _AnularVentaScreenState extends State<AnularVentaScreen> {
  final TextEditingController _comprobanteController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();
  final FocusNode _comprobanteFocusNode = FocusNode();
  final FocusNode _motivoFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _scrollFocusNode = FocusNode();

  Map<String, dynamic>? _ventaEncontrada;
  bool _buscando = false;
  bool _procesando = false;

  // Historial de ventas del día
  List<Map<String, dynamic>> _ventasDelDia = [];
  List<Map<String, dynamic>> _anulacionesDelDia = [];
  bool _cargandoHistorial = true;

  // Control de anulaciones para secretaria
  int _anulacionesUsuarioHoy = 0;

  @override
  void initState() {
    super.initState();
    // Auto-focus en el campo de comprobante
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _comprobanteFocusNode.requestFocus();
    });
    // Cargar historial de ventas del día
    _cargarHistorialVentas();
  }

  Future<void> _cargarHistorialVentas() async {
    setState(() {
      _cargandoHistorial = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final usuario = authProvider.currentUser?['username'] ?? 'desconocido';

      final cajaDb = CajaDatabase();
      final ventas = await cajaDb.getVentasDiarias();

      // Contar anulaciones del usuario hoy
      final anulacionesHoy = await cajaDb.contarAnulacionesDelDia(usuario);

      // Separar ventas activas y anuladas del día de hoy
      List<Map<String, dynamic>> ventasActivas = [];
      List<Map<String, dynamic>> ventasAnuladas = [];

      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (var venta in ventas) {
        // Filtrar solo las ventas de hoy
        if (venta['fecha'] == hoy) {
          if (venta['anulada'] == true) {
            ventasAnuladas.add(venta);
          } else {
            ventasActivas.add(venta);
          }
        }
      }

      setState(() {
        _ventasDelDia = ventasActivas;
        _anulacionesDelDia = ventasAnuladas;
        _anulacionesUsuarioHoy = anulacionesHoy;
        _cargandoHistorial = false;
      });
    } catch (e) {
      setState(() {
        _cargandoHistorial = false;
      });
      _mostrarMensaje('Error al cargar historial: $e', error: true);
    }
  }

  @override
  void dispose() {
    _comprobanteController.dispose();
    _motivoController.dispose();
    _comprobanteFocusNode.dispose();
    _motivoFocusNode.dispose();
    _scrollController.dispose();
    _scrollFocusNode.dispose();
    super.dispose();
  }

  // Manejar eventos de teclado para scroll
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

  Future<void> _buscarVenta() async {
    String comprobante = _comprobanteController.text.trim().toUpperCase();

    if (comprobante.isEmpty) {
      _mostrarMensaje('Por favor ingrese un número de comprobante', error: true);
      return;
    }

    setState(() {
      _buscando = true;
      _ventaEncontrada = null;
    });

    try {
      final cajaDb = CajaDatabase();
      final ventas = await cajaDb.getVentasDiarias();

      // Buscar la venta
      Map<String, dynamic>? venta;
      for (var v in ventas) {
        if (v['comprobante'] == comprobante) {
          venta = v;
          break;
        }
      }

      if (venta == null) {
        _mostrarMensaje('No se encontró ninguna venta con el comprobante $comprobante', error: true);
      } else if (venta['anulada'] == true) {
        _mostrarMensaje('Esta venta ya fue anulada anteriormente', error: true);
      } else {
        setState(() {
          _ventaEncontrada = venta;
        });
        _mostrarMensaje('Venta encontrada. Revise los detalles antes de anular.');
      }
    } catch (e) {
      _mostrarMensaje('Error al buscar la venta: $e', error: true);
    } finally {
      setState(() {
        _buscando = false;
      });
    }
  }

  Future<void> _confirmarAnulacion() async {
    if (_ventaEncontrada == null) {
      _mostrarMensaje('Primero debe buscar y encontrar una venta', error: true);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isSecretaria = authProvider.isSecretaria;

    String motivo = _motivoController.text.trim();

    // Validar motivo obligatorio
    if (motivo.isEmpty) {
      _mostrarMensaje('Debe ingresar un motivo para la anulación', error: true);
      _motivoFocusNode.requestFocus();
      return;
    }

    // Si es Secretaria y ya tiene 3 o más anulaciones, requiere justificación detallada
    if (isSecretaria && _anulacionesUsuarioHoy >= 3) {
      if (motivo.length < 30) {
        _mostrarMensaje(
          'Ha alcanzado el límite de 3 anulaciones. Se requiere una justificación detallada (mínimo 30 caracteres)',
          error: true,
        );
        _motivoFocusNode.requestFocus();
        return;
      }
    }

    // Confirmar con diálogo
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Confirmar Anulación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Está seguro de anular esta venta?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('Comprobante: ${_ventaEncontrada!['comprobante']}'),
            Text('Valor: \$${_ventaEncontrada!['valor']}'),
            if (_ventaEncontrada!['tipo'] == 'bus')
              Text('Asiento: ${_ventaEncontrada!['asiento']}'),
            SizedBox(height: 12),
            Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ANULAR VENTA'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Procesar anulación
    setState(() {
      _procesando = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final usuario = authProvider.currentUser?['username'] ?? 'desconocido';

      final cajaDb = CajaDatabase();
      final resultado = await cajaDb.anularVenta(
        comprobante: _ventaEncontrada!['comprobante'],
        usuario: usuario,
        motivo: motivo,
      );

      if (resultado) {
        _mostrarMensaje('Venta anulada exitosamente', success: true);

        // Recargar historial
        await _cargarHistorialVentas();

        // Limpiar formulario
        setState(() {
          _ventaEncontrada = null;
          _comprobanteController.clear();
          _motivoController.clear();
        });

        _comprobanteFocusNode.requestFocus();
      } else {
        _mostrarMensaje('No se pudo anular la venta. Verifique el comprobante.', error: true);
      }
    } catch (e) {
      _mostrarMensaje('Error al anular la venta: $e', error: true);
    } finally {
      setState(() {
        _procesando = false;
      });
    }
  }

  void _mostrarMensaje(String mensaje, {bool error = false, bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error : (success ? Icons.check_circle : Icons.info),
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: error ? Colors.red : (success ? Colors.green : Colors.blue),
        duration: Duration(seconds: error ? 4 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _scrollFocusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.cancel, size: 28),
              SizedBox(width: 12),
              Text('Anular Venta'),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.red.shade700,
          elevation: 2,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.shade50.withOpacity(0.3),
                Colors.white,
              ],
            ),
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 8,
            radius: Radius.circular(4),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Advertencia
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 32),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Advertencia Importante',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'La anulación de ventas es una acción permanente. Asegúrese de verificar toda la información antes de proceder.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contador de anulaciones para secretaria
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      if (!authProvider.isSecretaria) return SizedBox.shrink();

                      final anulacionesRestantes = 3 - _anulacionesUsuarioHoy;
                      final color = _anulacionesUsuarioHoy >= 3
                          ? Colors.red
                          : (_anulacionesUsuarioHoy >= 2 ? Colors.orange : Colors.blue);

                      return Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.shade300, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: color.shade700, size: 28),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Control de Anulaciones',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: color.shade900,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _anulacionesUsuarioHoy >= 3
                                        ? 'Ha alcanzado el límite de 3 anulaciones. Se requiere justificación detallada.'
                                        : 'Anulaciones hoy: $_anulacionesUsuarioHoy de 3. Quedan $anulacionesRestantes anulaciones simples.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: color.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 32),

                  // Buscar venta
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Buscar Venta',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Ingrese el número de comprobante',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _comprobanteController,
                                focusNode: _comprobanteFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Ej: AYS-01-000123',
                                  prefixIcon: Icon(Icons.receipt_long),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                textCapitalization: TextCapitalization.characters,
                                onFieldSubmitted: (_) => _buscarVenta(),
                              ),
                            ),
                            SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _buscando ? null : _buscarVenta,
                              icon: _buscando
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(Icons.search),
                              label: Text('Buscar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Detalles de la venta
                  if (_ventaEncontrada != null) ...[
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _ventaEncontrada!['tipo'] == 'bus'
                                      ? Icons.directions_bus
                                      : Icons.inventory,
                                  color: Colors.blue.shade700,
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '2. Detalles de la Venta',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    Text(
                                      _ventaEncontrada!['tipo'] == 'bus'
                                          ? 'Venta de Pasaje'
                                          : 'Venta de Carga',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Divider(),
                          SizedBox(height: 12),
                          _buildDetalleRow('Comprobante', _ventaEncontrada!['comprobante'], bold: true),
                          _buildDetalleRow('Fecha', _ventaEncontrada!['fecha']),
                          _buildDetalleRow('Hora', _ventaEncontrada!['hora']),
                          if (_ventaEncontrada!['tipo'] == 'bus') ...[
                            _buildDetalleRow('Destino', _ventaEncontrada!['destino']),
                            _buildDetalleRow('Horario', _ventaEncontrada!['horario']),
                            _buildDetalleRow('Asiento', _ventaEncontrada!['asiento']),
                            _buildDetalleRow('Tipo de Boleto', _ventaEncontrada!['tipoBoleto']),
                          ] else ...[
                            _buildDetalleRow('Remitente', _ventaEncontrada!['remitente']),
                            _buildDetalleRow('Destinatario', _ventaEncontrada!['destinatario']),
                            _buildDetalleRow('Destino', _ventaEncontrada!['destino']),
                            _buildDetalleRow('Artículo', _ventaEncontrada!['articulo']),
                          ],
                          _buildDetalleRow('Método de Pago', _ventaEncontrada!['metodoPago']),
                          Divider(),
                          _buildDetalleRow(
                            'VALOR TOTAL',
                            '\$${_ventaEncontrada!['valor'].toStringAsFixed(0)}',
                            bold: true,
                            valueColor: Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Motivo de anulación
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3. Motivo de Anulación',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _motivoController,
                            focusNode: _motivoFocusNode,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Describa el motivo de la anulación (obligatorio)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // Botón de anular
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _procesando ? null : _confirmarAnulacion,
                        icon: _procesando
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.cancel, size: 28),
                        label: Text(
                          _procesando ? 'Procesando...' : 'ANULAR VENTA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 32),

                  // Historial de ventas del día
                  _buildHistorialSection(),

                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorialSection() {
    if (_cargandoHistorial) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ventas del día
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ventas Activas del Día',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_ventasDelDia.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_ventasDelDia.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No hay ventas activas hoy',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _ventasDelDia.length > 5 ? 5 : _ventasDelDia.length,
                  itemBuilder: (context, index) {
                    return _buildVentaCard(_ventasDelDia[index], false);
                  },
                ),
              if (_ventasDelDia.length > 5)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Mostrando 5 de ${_ventasDelDia.length} ventas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // Anulaciones del día
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red.shade700, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Anulaciones del Día',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_anulacionesDelDia.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_anulacionesDelDia.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No hay anulaciones hoy',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _anulacionesDelDia.length,
                  itemBuilder: (context, index) {
                    return _buildVentaCard(_anulacionesDelDia[index], true);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVentaCard(Map<String, dynamic> venta, bool esAnulada) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: esAnulada ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esAnulada ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    venta['tipo'] == 'bus' ? Icons.directions_bus : Icons.inventory,
                    color: esAnulada ? Colors.red.shade700 : Colors.green.shade700,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    venta['comprobante'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${venta['valor'].toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: esAnulada ? Colors.red.shade700 : Colors.green.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Hora: ${venta['hora']} | ${venta['tipo'] == 'bus' ? 'Destino: ${venta['destino']}' : 'Cargo: ${venta['articulo']}'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          if (esAnulada) ...[
            SizedBox(height: 8),
            Text(
              'Anulada: ${venta['fechaAnulacion']} ${venta['horaAnulacion']}',
              style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontStyle: FontStyle.italic),
            ),
            Text(
              'Usuario: ${venta['usuarioAnulacion']}',
              style: TextStyle(fontSize: 11, color: Colors.red.shade600),
            ),
            Text(
              'Motivo: ${venta['motivoAnulacion']}',
              style: TextStyle(fontSize: 11, color: Colors.red.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
