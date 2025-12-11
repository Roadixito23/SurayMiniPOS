import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comprobante.dart';
import '../models/auth_provider.dart';
import '../models/admin_code_manager.dart';
import '../services/cloud_api_service.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _secretController = TextEditingController();
  final FocusNode _secretFocusNode = FocusNode();
  bool _showAdminSection = false;
  String? _currentCode;
  DateTime? _codeGeneratedAt;

  // Configuración del servidor cloud
  final TextEditingController _serverUrlController = TextEditingController();
  bool _modoSoloOffline = false;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    _secretController.addListener(_checkSecretWord);
    _loadCurrentCode();
    _loadCloudSettings();
  }

  Future<void> _loadCurrentCode() async {
    final adminCodeManager = AdminCodeManager();
    final code = await adminCodeManager.getCurrentCode();
    final generatedAt = await adminCodeManager.getCodeGeneratedAt();

    setState(() {
      _currentCode = code;
      _codeGeneratedAt = generatedAt;
    });
  }

  void _checkSecretWord() {
    if (_secretController.text.toLowerCase() == 'administrador') {
      setState(() {
        _showAdminSection = true;
      });
      _secretController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.white),
              SizedBox(width: 12),
              Text('Sección de administrador desbloqueada'),
            ],
          ),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadCloudSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('cloud_api_url') ?? CloudApiService.defaultBaseUrl;
      final offline = prefs.getBool('modo_solo_offline') ?? false;

      setState(() {
        _serverUrlController.text = url;
        _modoSoloOffline = offline;
      });
    } catch (e) {
      debugPrint('Error cargando configuración cloud: $e');
    }
  }

  Future<void> _saveServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cloud_api_url', _serverUrlController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('URL del servidor guardada'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleModoOffline(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('modo_solo_offline', value);

      setState(() {
        _modoSoloOffline = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Modo solo offline activado' : 'Modo solo offline desactivado'),
          backgroundColor: value ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
    });

    try {
      final connected = await CloudApiService.verificarConexion();

      if (mounted) {
        setState(() {
          _testingConnection = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  connected ? Icons.check_circle : Icons.error,
                  color: connected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 12),
                Text(connected ? 'Conexión exitosa' : 'Sin conexión'),
              ],
            ),
            content: Text(
              connected
                  ? 'La conexión con el servidor cloud es exitosa.'
                  : 'No se pudo conectar con el servidor. Verifica la URL y tu conexión a internet.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CERRAR'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testingConnection = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 12),
                Text('Error'),
              ],
            ),
            content: Text('Error al probar la conexión: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CERRAR'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _secretController.dispose();
    _secretFocusNode.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _cerrarSesion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Está seguro que desea cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Provider.of<AuthProvider>(context, listen: false).logout();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _resetReceiptNumber() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar reinicio'),
          content: Text('¿Está seguro que desea reiniciar el número de comprobante a 1?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Reiniciar',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                // Usar el ComprobanteManager para reiniciar
                await ComprobanteManager().resetCounter();
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Número de comprobante reiniciado a 1'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del usuario actual
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF1976D2),
                      radius: 24,
                      child: Icon(
                        isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authProvider.username,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            authProvider.rol,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Sección de comprobantes
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Comprobantes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Reiniciar la numeración de comprobantes volverá a empezar desde el número 1.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _resetReceiptNumber,
                        icon: Icon(Icons.restart_alt),
                        label: Text('Reiniciar Número'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
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

            SizedBox(height: 24),

            // Campo secreto para desbloquear sección de administrador (solo para admin)
            if (isAdmin && !_showAdminSection)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'Acceso Especial',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _secretController,
                        focusNode: _secretFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Escribe la palabra secreta...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                      ),
                    ],
                  ),
                ),
              ),

            // Sección de códigos de anulación (solo visible para admin cuando se desbloquea)
            if (isAdmin && _showAdminSection) _buildAdminCodeSection(),

            SizedBox(height: 24),

            // Configuración del servidor cloud
            _buildCloudServerSection(),

            SizedBox(height: 24),

            // Información adicional
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'El resto de configuraciones están disponibles en otras secciones de la aplicación.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCodeSection() {
    return Card(
      elevation: 4,
      color: Colors.purple.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.purple, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Códigos de Anulación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.purple),
                  onPressed: () {
                    setState(() {
                      _showAdminSection = false;
                    });
                  },
                  tooltip: 'Cerrar sección',
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.purple, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Código para Anulaciones Adicionales',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Las secretarias tienen un límite de 3 anulaciones por día. Para anular más ventas, necesitan ingresar un código de administrador.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (_currentCode != null) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade100, Colors.purple.shade200],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_key, color: Colors.purple.shade700),
                        SizedBox(width: 8),
                        Text(
                          'Código Actual',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentCode!,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 12,
                            color: Colors.purple.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    if (_codeGeneratedAt != null) ...[
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(_codeGeneratedAt!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.purple.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final adminCodeManager = AdminCodeManager();
                      final newCode = await adminCodeManager.generateNewCode();

                      await _loadCurrentCode();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('Nuevo código generado: $newCode'),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Generar Nuevo Código'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (_currentCode != null) ...[
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Eliminar Código'),
                          content: Text('¿Está seguro de eliminar el código actual?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('CANCELAR'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: Text('ELIMINAR'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final adminCodeManager = AdminCodeManager();
                        await adminCodeManager.clearCode();
                        await _loadCurrentCode();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Código eliminado'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.delete),
                    label: Text('Eliminar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudServerSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, color: Colors.blue.shade700),
                SizedBox(width: 8),
                Text(
                  'Servidor Cloud',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'URL del servidor:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                hintText: 'https://suraypos.example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.link),
                suffixIcon: IconButton(
                  icon: Icon(Icons.save),
                  onPressed: _saveServerUrl,
                  tooltip: 'Guardar URL',
                ),
              ),
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Modo Solo Offline'),
              subtitle: Text(
                _modoSoloOffline
                    ? 'La sincronización está desactivada'
                    : 'La sincronización está activa',
                style: TextStyle(fontSize: 12),
              ),
              value: _modoSoloOffline,
              onChanged: _toggleModoOffline,
              secondary: Icon(
                _modoSoloOffline ? Icons.cloud_off : Icons.cloud_done,
                color: _modoSoloOffline ? Colors.orange : Colors.green,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testingConnection ? null : _testConnection,
                icon: _testingConnection
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(Icons.wifi_find),
                label: Text(_testingConnection ? 'Probando...' : 'Probar Conexión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
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
                      'El sistema funciona 100% offline. La sincronización es opcional.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}