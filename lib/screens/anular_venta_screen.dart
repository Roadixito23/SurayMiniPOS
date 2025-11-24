import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../database/caja_database.dart';
import '../database/app_database.dart';
import '../models/auth_provider.dart';
import '../models/admin_code_manager.dart';

class AnularVentaScreen extends StatefulWidget {
  @override
  _AnularVentaScreenState createState() => _AnularVentaScreenState();
}

class _AnularVentaScreenState extends State<AnularVentaScreen> {
  final TextEditingController _comprobanteController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();
  final TextEditingController _idVendedorController = TextEditingController();
  final FocusNode _comprobanteFocusNode = FocusNode();
  final FocusNode _motivoFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _ventaEncontrada;
  bool _buscando = false;
  bool _procesando = false;

  // Filtros
  String _filtroTiempo = 'hoy'; // hoy, semana, mes, todos
  String? _filtroSucursal; // AYS, COY, null (todos)
  bool _mostrarAnulados = true;
  bool _mostrarActivos = true;

  // Resultados de búsqueda
  List<Map<String, dynamic>> _boletosEncontrados = [];
  bool _cargandoBoletos = false;

  // Control de anulaciones para secretaria
  int _anulacionesUsuarioHoy = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarAnulacionesUsuario();
      _buscarBoletosConFiltros();
    });
  }

  @override
  void dispose() {
    _comprobanteController.dispose();
    _motivoController.dispose();
    _idVendedorController.dispose();
    _comprobanteFocusNode.dispose();
    _motivoFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarAnulacionesUsuario() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final usuario = authProvider.currentUser?['username'] ?? 'desconocido';

      final appDb = AppDatabase.instance;
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final contador = await appDb.contarAnulacionesUsuario(usuario, hoy);

      setState(() {
        _anulacionesUsuarioHoy = contador;
      });
    } catch (e) {
      debugPrint('Error al cargar anulaciones: $e');
    }
  }

  Future<void> _buscarBoletosConFiltros() async {
    setState(() {
      _cargandoBoletos = true;
      _boletosEncontrados = [];
    });

    try {
      final appDb = AppDatabase.instance;
      final ahora = DateTime.now();

      // Calcular fechas según filtro
      String? fechaInicio;
      String? fechaFin;

      switch (_filtroTiempo) {
        case 'hoy':
          fechaInicio = DateFormat('yyyy-MM-dd').format(ahora);
          fechaFin = fechaInicio;
          break;
        case 'semana':
          fechaInicio = DateFormat('yyyy-MM-dd').format(ahora.subtract(Duration(days: 7)));
          fechaFin = DateFormat('yyyy-MM-dd').format(ahora);
          break;
        case 'mes':
          fechaInicio = DateFormat('yyyy-MM-dd').format(ahora.subtract(Duration(days: 30)));
          fechaFin = DateFormat('yyyy-MM-dd').format(ahora);
          break;
        case 'todos':
          // No filtrar por fecha
          break;
      }

      // Buscar boletos
      final boletos = await appDb.getBoletos(
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        sucursal: _filtroSucursal,
        idVendedor: _idVendedorController.text.trim().isEmpty
            ? null
            : _idVendedorController.text.trim(),
        comprobante: _comprobanteController.text.trim().isEmpty
            ? null
            : _comprobanteController.text.trim(),
      );

      // Filtrar por estado (activos/anulados)
      List<Map<String, dynamic>> boletosFiltrados = [];
      for (var boleto in boletos) {
        final esAnulado = boleto['anulado'] == 1;
        if ((_mostrarActivos && !esAnulado) || (_mostrarAnulados && esAnulado)) {
          boletosFiltrados.add(boleto);
        }
      }

      setState(() {
        _boletosEncontrados = boletosFiltrados;
        _cargandoBoletos = false;
      });
    } catch (e) {
      setState(() {
        _cargandoBoletos = false;
      });
      _mostrarMensaje('Error al buscar boletos: $e', error: true);
    }
  }

  Future<void> _seleccionarBoleto(Map<String, dynamic> boleto) async {
    if (boleto['anulado'] == 1) {
      _mostrarMensaje('Este boleto ya está anulado', error: true);
      return;
    }

    // Verificar si puede ser anulado (4 horas)
    final appDb = AppDatabase.instance;
    final puedeAnular = await appDb.verificarBoletoAnulable(boleto['comprobante']);

    if (!puedeAnular) {
      _mostrarMensaje(
        'No se puede anular este boleto. Los boletos de bus solo pueden anularse si faltan más de 4 horas para la salida.',
        error: true,
      );
      return;
    }

    // Parsear datos completos
    try {
      final datosCompletos = jsonDecode(boleto['datos_completos']);
      setState(() {
        _ventaEncontrada = datosCompletos;
        _comprobanteController.text = boleto['comprobante'];
      });

      // Scroll hacia el formulario de anulación
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      _mostrarMensaje('Boleto seleccionado. Complete el motivo de anulación.');
    } catch (e) {
      _mostrarMensaje('Error al cargar datos del boleto: $e', error: true);
    }
  }

  Future<void> _confirmarAnulacion() async {
    if (_ventaEncontrada == null) {
      _mostrarMensaje('Primero debe seleccionar un boleto para anular', error: true);
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

    // Si es Secretaria y ya tiene 3 o más anulaciones, solicitar código de administrador
    if (isSecretaria && _anulacionesUsuarioHoy >= 3) {
      final codigoValido = await _solicitarCodigoAdministrador();
      if (codigoValido != true) {
        return;
      }
    }

    // Confirmar con diálogo
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

      // Anular en base de datos SQLite
      final appDb = AppDatabase.instance;
      await appDb.anularBoleto(
        comprobante: _ventaEncontrada!['comprobante'],
        usuario: usuario,
        motivo: motivo,
      );

      // Anular en JSON
      final cajaDb = CajaDatabase();
      await cajaDb.anularVenta(
        comprobante: _ventaEncontrada!['comprobante'],
        usuario: usuario,
        motivo: motivo,
      );

      _mostrarMensaje('Venta anulada exitosamente', success: true);

      // Recargar datos
      await _cargarAnulacionesUsuario();
      await _buscarBoletosConFiltros();

      // Limpiar formulario
      setState(() {
        _ventaEncontrada = null;
        _motivoController.clear();
      });
    } catch (e) {
      _mostrarMensaje('Error al anular la venta: $e', error: true);
    } finally {
      setState(() {
        _procesando = false;
      });
    }
  }

  Future<bool?> _solicitarCodigoAdministrador() async {
    final TextEditingController codigoController = TextEditingController();
    final adminCodeManager = AdminCodeManager();

    final hasCode = await adminCodeManager.hasActiveCode();
    if (!hasCode) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Código No Disponible'),
            ],
          ),
          content: Text(
            'No hay código de administrador generado. Por favor, solicite al administrador que genere un código desde Configuración.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ENTENDIDO'),
            ),
          ],
        ),
      );
      return false;
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Código de Administrador',
                style: TextStyle(color: Colors.orange.shade700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ha alcanzado el límite de 3 anulaciones. Ingrese el código de administrador para continuar.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: codigoController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 5,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                labelText: 'Código de 5 dígitos',
                hintText: '12345',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
                counterText: '',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              final codigo = codigoController.text.trim();
              if (codigo.length != 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('El código debe tener 5 dígitos'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final esValido = await adminCodeManager.verifyCode(codigo);
              if (esValido) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Código válido. Puede proceder con la anulación.'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.error, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Código incorrecto. Intente nuevamente.'),
                      ],
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('VERIFICAR'),
          ),
        ],
      ),
    );
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
    return Scaffold(
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
        child: Column(
          children: [
            // Panel de filtros
            _buildFiltrosPanel(),

            // Contenido principal
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Contador de anulaciones
                      _buildContadorAnulaciones(),

                      SizedBox(height: 16),

                      // Lista de boletos
                      _buildListaBoletos(),

                      // Formulario de anulación (solo si hay boleto seleccionado)
                      if (_ventaEncontrada != null) ...[
                        SizedBox(height: 24),
                        _buildFormularioAnulacion(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltrosPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtros de Búsqueda',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 12),

          // Filtro de tiempo
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFiltroChip('Hoy', 'hoy', Icons.today),
              _buildFiltroChip('Última semana', 'semana', Icons.calendar_view_week),
              _buildFiltroChip('Último mes', 'mes', Icons.calendar_month),
              _buildFiltroChip('Todos', 'todos', Icons.all_inclusive),
            ],
          ),

          SizedBox(height: 12),

          // Filtro de sucursal y búsqueda
          Row(
            children: [
              // Sucursal
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filtroSucursal,
                  decoration: InputDecoration(
                    labelText: 'Sucursal',
                    prefixIcon: Icon(Icons.location_on, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('Todas')),
                    DropdownMenuItem(value: 'AYS', child: Text('AYS (Aysén)')),
                    DropdownMenuItem(value: 'COY', child: Text('COY (Coyhaique)')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filtroSucursal = value;
                    });
                    _buscarBoletosConFiltros();
                  },
                ),
              ),
              SizedBox(width: 8),

              // ID Vendedor
              Expanded(
                child: TextField(
                  controller: _idVendedorController,
                  decoration: InputDecoration(
                    labelText: 'ID Vendedor',
                    hintText: '01',
                    prefixIcon: Icon(Icons.badge, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (_) => _buscarBoletosConFiltros(),
                ),
              ),
              SizedBox(width: 8),

              // Número de serie
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _comprobanteController,
                  focusNode: _comprobanteFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Número de Serie',
                    hintText: 'AYS-01-000123',
                    prefixIcon: Icon(Icons.receipt_long, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => _buscarBoletosConFiltros(),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Filtro de estado
          Row(
            children: [
              Text('Mostrar: ', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              FilterChip(
                label: Text('Activos'),
                selected: _mostrarActivos,
                onSelected: (value) {
                  setState(() {
                    _mostrarActivos = value;
                  });
                  _buscarBoletosConFiltros();
                },
                selectedColor: Colors.green.shade100,
                checkmarkColor: Colors.green.shade700,
              ),
              SizedBox(width: 8),
              FilterChip(
                label: Text('Anulados'),
                selected: _mostrarAnulados,
                onSelected: (value) {
                  setState(() {
                    _mostrarAnulados = value;
                  });
                  _buscarBoletosConFiltros();
                },
                selectedColor: Colors.red.shade100,
                checkmarkColor: Colors.red.shade700,
              ),
              Spacer(),
              TextButton.icon(
                onPressed: _buscarBoletosConFiltros,
                icon: Icon(Icons.refresh),
                label: Text('Actualizar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, String value, IconData icon) {
    final isSelected = _filtroTiempo == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.blue.shade700 : Colors.grey),
          SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filtroTiempo = value;
          });
          _buscarBoletosConFiltros();
        }
      },
      selectedColor: Colors.blue.shade100,
    );
  }

  Widget _buildContadorAnulaciones() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isSecretaria) return SizedBox.shrink();

        final anulacionesRestantes = 3 - _anulacionesUsuarioHoy;
        final color = _anulacionesUsuarioHoy >= 3
            ? Colors.red
            : (_anulacionesUsuarioHoy >= 2 ? Colors.orange : Colors.blue);

        return Container(
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
                          ? 'Ha alcanzado el límite máximo de 3 anulaciones del día. Contacte a un administrador.'
                          : 'Anulaciones realizadas hoy: $_anulacionesUsuarioHoy de 3. Le quedan $anulacionesRestantes.',
                      style: TextStyle(
                        fontSize: 13,
                        color: color.shade800,
                        fontWeight: _anulacionesUsuarioHoy >= 3 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListaBoletos() {
    if (_cargandoBoletos) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_boletosEncontrados.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              'No se encontraron boletos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Intente ajustar los filtros de búsqueda',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Resultados (${_boletosEncontrados.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _boletosEncontrados.length,
          itemBuilder: (context, index) {
            return _buildBoletoCard(_boletosEncontrados[index]);
          },
        ),
      ],
    );
  }

  Widget _buildBoletoCard(Map<String, dynamic> boleto) {
    final esAnulado = boleto['anulado'] == 1;
    final esBus = boleto['tipo'] == 'bus';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: esAnulado ? null : () => _seleccionarBoleto(boleto),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: esAnulado ? Colors.red.shade200 : Colors.green.shade200,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: esAnulado ? Colors.red.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      esBus ? Icons.directions_bus : Icons.inventory,
                      color: esAnulado ? Colors.red.shade700 : Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          boleto['comprobante'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${boleto['sucursal']} - ID ${boleto['id_vendedor']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${boleto['valor'].toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: esAnulado ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: 4),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: esAnulado ? Colors.red.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          esAnulado ? 'ANULADO' : 'ACTIVO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: esAnulado ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
              Divider(height: 1),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      boleto['fecha_venta'] ?? '',
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.access_time,
                      boleto['hora_venta'] ?? '',
                    ),
                  ),
                  if (esBus && boleto['destino'] != null)
                    Expanded(
                      child: _buildInfoItem(
                        Icons.location_on,
                        boleto['destino'],
                      ),
                    ),
                ],
              ),
              if (esAnulado) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anulado: ${boleto['fecha_anulacion']} ${boleto['hora_anulacion']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Usuario: ${boleto['usuario_anulacion']}',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                      ),
                      Text(
                        'Motivo: ${boleto['motivo_anulacion']}',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFormularioAnulacion() {
    return Container(
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
                  'Anular Boleto Seleccionado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comprobante: ${_ventaEncontrada!['comprobante']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Valor: \$${_ventaEncontrada!['valor']}'),
                if (_ventaEncontrada!['tipo'] == 'bus')
                  Text('Asiento: ${_ventaEncontrada!['asiento']}'),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Motivo de Anulación *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
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
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
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
      ),
    );
  }
}
