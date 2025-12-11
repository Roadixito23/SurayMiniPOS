import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cloud_api_service.dart';
import '../models/auth_provider.dart';
import '../database/app_database.dart';
import 'package:intl/intl.dart';

class SincronizacionScreen extends StatefulWidget {
  const SincronizacionScreen({Key? key}) : super(key: key);

  @override
  State<SincronizacionScreen> createState() => _SincronizacionScreenState();
}

class _SincronizacionScreenState extends State<SincronizacionScreen> {
  bool _isSyncing = false;
  String _syncStatus = '';
  Map<String, dynamic>? _lastSyncResult;
  DateTime? _ultimaSincronizacion;
  int _ventasPendientes = 0;
  int _cierresPendientes = 0;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _checkConnection(),
      _loadUltimaSincronizacion(),
      _loadVentasPendientes(),
      _loadCierresPendientes(),
    ]);
  }

  Future<void> _checkConnection() async {
    try {
      final connected = await CloudApiService.verificarConexion();
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  Future<void> _loadUltimaSincronizacion() async {
    try {
      final ultimaSync = await CloudApiService.getUltimaSincronizacion();
      if (mounted) {
        setState(() {
          _ultimaSincronizacion = ultimaSync;
        });
      }
    } catch (e) {
      debugPrint('Error cargando última sincronización: $e');
    }
  }

  Future<void> _loadVentasPendientes() async {
    try {
      final db = AppDatabase.instance;
      final ventas = await db.obtenerVentasNoSincronizadas();
      if (mounted) {
        setState(() {
          _ventasPendientes = ventas.length;
        });
      }
    } catch (e) {
      debugPrint('Error cargando ventas pendientes: $e');
    }
  }

  Future<void> _loadCierresPendientes() async {
    try {
      final db = AppDatabase.instance;
      final cierres = await db.obtenerCierresNoSincronizados();
      if (mounted) {
        setState(() {
          _cierresPendientes = cierres.length;
        });
      }
    } catch (e) {
      debugPrint('Error cargando cierres pendientes: $e');
    }
  }

  Future<void> _sincronizarTodo() async {
    if (_isSyncing) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sucursal = authProvider.sucursalActual ?? 'AYS';

    setState(() {
      _isSyncing = true;
      _syncStatus = 'Iniciando sincronización...';
      _lastSyncResult = null;
    });

    try {
      // Verificar conexión
      setState(() => _syncStatus = 'Verificando conexión...');
      final connected = await CloudApiService.verificarConexion();

      if (!connected) {
        _showError('No hay conexión con el servidor cloud');
        setState(() => _isSyncing = false);
        return;
      }

      // Descargar tarifas
      setState(() => _syncStatus = 'Descargando tarifas...');
      await Future.delayed(Duration(milliseconds: 500));
      final tarifasOk = await CloudApiService.descargarTarifas(sucursal);

      // Descargar horarios
      setState(() => _syncStatus = 'Descargando horarios...');
      await Future.delayed(Duration(milliseconds: 500));
      final horariosOk = await CloudApiService.descargarHorarios(sucursal);

      // Descargar usuarios
      setState(() => _syncStatus = 'Descargando usuarios...');
      await Future.delayed(Duration(milliseconds: 500));
      final usuariosOk = await CloudApiService.descargarUsuarios();

      // Subir ventas pendientes
      setState(() => _syncStatus = 'Subiendo ventas pendientes...');
      await Future.delayed(Duration(milliseconds: 500));
      final ventasResult = await CloudApiService.sincronizarVentasLocal();

      // Subir cierres pendientes
      setState(() => _syncStatus = 'Subiendo cierres de caja...');
      await Future.delayed(Duration(milliseconds: 500));
      final cierresResult = await CloudApiService.sincronizarCierresLocal();

      final result = {
        'tarifas': tarifasOk,
        'horarios': horariosOk,
        'usuarios': usuariosOk,
        'ventas': ventasResult,
        'cierres': cierresResult,
      };

      setState(() {
        _syncStatus = '¡Sincronización completada!';
        _lastSyncResult = result;
        _isSyncing = false;
      });

      // Recargar datos
      await _loadData();

      _showSuccess('Sincronización completada exitosamente');
    } catch (e) {
      setState(() {
        _syncStatus = 'Error en sincronización';
        _isSyncing = false;
      });
      _showError('Error durante la sincronización: $e');
    }
  }

  Future<void> _descargarTarifas() async {
    if (_isSyncing) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sucursal = authProvider.sucursalActual ?? 'AYS';

    setState(() => _isSyncing = true);

    try {
      final success = await CloudApiService.descargarTarifas(sucursal);
      setState(() => _isSyncing = false);

      if (success) {
        _showSuccess('Tarifas descargadas exitosamente');
      } else {
        _showError('Error al descargar tarifas');
      }
    } catch (e) {
      setState(() => _isSyncing = false);
      _showError('Error: $e');
    }
  }

  Future<void> _descargarHorarios() async {
    if (_isSyncing) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sucursal = authProvider.sucursalActual ?? 'AYS';

    setState(() => _isSyncing = true);

    try {
      final success = await CloudApiService.descargarHorarios(sucursal);
      setState(() => _isSyncing = false);

      if (success) {
        _showSuccess('Horarios descargados exitosamente');
      } else {
        _showError('Error al descargar horarios');
      }
    } catch (e) {
      setState(() => _isSyncing = false);
      _showError('Error: $e');
    }
  }

  Future<void> _subirVentas() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final result = await CloudApiService.sincronizarVentasLocal();
      setState(() => _isSyncing = false);

      await _loadVentasPendientes();

      if (result['success']) {
        _showSuccess('${result['enviados']} ventas sincronizadas');
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      setState(() => _isSyncing = false);
      _showError('Error: $e');
    }
  }

  Future<void> _subirCierres() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final result = await CloudApiService.sincronizarCierresLocal();
      setState(() => _isSyncing = false);

      await _loadCierresPendientes();

      if (result['success']) {
        _showSuccess('${result['enviados']} cierres sincronizados');
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      setState(() => _isSyncing = false);
      _showError('Error: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sincronización Cloud'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar información',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado de conexión
            _buildConnectionCard(),
            SizedBox(height: 24),

            // Botón principal
            _buildSyncAllButton(),
            SizedBox(height: 24),

            // Estadísticas
            _buildStatsSection(),
            SizedBox(height: 24),

            // Botones individuales
            _buildIndividualButtons(),
            SizedBox(height: 24),

            // Resultado de última sincronización
            if (_lastSyncResult != null) _buildSyncResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    Color statusColor = _isConnected ? Colors.green : Colors.red;
    IconData statusIcon = _isConnected ? Icons.cloud_done : Icons.cloud_off;
    String statusText = _isConnected ? 'Conectado al servidor' : 'Sin conexión';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 32),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (_ultimaSincronizacion != null) ...[
                    SizedBox(height: 4),
                    Text(
                      'Última sincronización: ${DateFormat('dd/MM/yyyy HH:mm').format(_ultimaSincronizacion!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: 4),
                    Text(
                      'Sin sincronizaciones previas',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncAllButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _isSyncing || !_isConnected ? null : _sincronizarTodo,
        icon: _isSyncing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.sync, size: 28),
        label: Text(
          _isSyncing ? _syncStatus : 'SINCRONIZAR TODO',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estadísticas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Ventas Pendientes',
                _ventasPendientes.toString(),
                Icons.receipt,
                Colors.orange,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Cierres Pendientes',
                _cierresPendientes.toString(),
                Icons.calculate,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sincronización Individual',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 12),
        _buildActionButton(
          'Descargar Tarifas desde Cloud',
          Icons.download,
          Colors.green,
          _descargarTarifas,
        ),
        SizedBox(height: 12),
        _buildActionButton(
          'Descargar Horarios desde Cloud',
          Icons.schedule,
          Colors.teal,
          _descargarHorarios,
        ),
        SizedBox(height: 12),
        _buildActionButton(
          'Subir Ventas Pendientes',
          Icons.upload,
          Colors.orange,
          _subirVentas,
        ),
        SizedBox(height: 12),
        _buildActionButton(
          'Subir Cierres de Caja',
          Icons.cloud_upload,
          Colors.purple,
          _subirCierres,
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSyncing || !_isConnected ? null : onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncResult() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                SizedBox(width: 8),
                Text(
                  'Resultado de la Sincronización',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildResultItem('Tarifas', _lastSyncResult!['tarifas']),
            _buildResultItem('Horarios', _lastSyncResult!['horarios']),
            _buildResultItem('Usuarios', _lastSyncResult!['usuarios']),
            _buildResultItem(
              'Ventas',
              _lastSyncResult!['ventas']['success'],
              details: '${_lastSyncResult!['ventas']['enviados']} enviadas',
            ),
            _buildResultItem(
              'Cierres',
              _lastSyncResult!['cierres']['success'],
              details: '${_lastSyncResult!['cierres']['enviados']} enviados',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(String label, bool success, {String? details}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (details != null) ...[
                  SizedBox(height: 2),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            success ? 'Exitoso' : 'Fallido',
            style: TextStyle(
              fontSize: 13,
              color: success ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
