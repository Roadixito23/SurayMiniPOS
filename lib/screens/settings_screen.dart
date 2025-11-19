import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/comprobante.dart';
import '../models/auth_provider.dart';
import '../models/server_status_provider.dart';
import '../models/admin_code_manager.dart';
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

  @override
  void initState() {
    super.initState();
    _secretController.addListener(_checkSecretWord);
    _loadCurrentCode();
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

  @override
  void dispose() {
    _secretController.dispose();
    _secretFocusNode.dispose();
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

            // Sección de Debug (solo visible para admin)
            if (isAdmin) _buildDebugSection(),

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

  Widget _buildDebugSection() {
    final serverStatus = Provider.of<ServerStatusProvider>(context);

    return Card(
      elevation: 4,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Ajustes de Debug',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado del Servidor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              serverStatus.statusMessage,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(serverStatus.statusColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey.shade300),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: serverStatus.isSimulated
                        ? (serverStatus.isOnline ? Colors.green.shade50 : Colors.red.shade50)
                        : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SwitchListTile(
                      value: serverStatus.isSimulated ? serverStatus.isOnline : true,
                      onChanged: (bool value) async {
                        await serverStatus.simulateServerStatus(value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  value ? Icons.cloud_done : Icons.cloud_off,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  value
                                    ? 'Servidor simulado: ONLINE'
                                    : 'Servidor simulado: OFFLINE',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            backgroundColor: value ? Colors.green : Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      title: Row(
                        children: [
                          Icon(
                            serverStatus.isSimulated
                              ? (serverStatus.isOnline ? Icons.cloud_done : Icons.cloud_off)
                              : Icons.cloud_queue,
                            color: serverStatus.isSimulated
                              ? (serverStatus.isOnline ? Colors.green : Colors.red)
                              : Colors.grey,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Simular Estado del Servidor',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  serverStatus.isSimulated
                                    ? (serverStatus.isOnline ? 'Servidor ONLINE' : 'Servidor OFFLINE')
                                    : 'Sin simulación',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                      inactiveTrackColor: Colors.red.shade200,
                    ),
                  ),
                  if (serverStatus.isSimulated) ...[
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          await serverStatus.resetSimulation();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Simulación desactivada'),
                              backgroundColor: Colors.blue,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(Icons.refresh, size: 18),
                        label: Text('Resetear Simulación'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cuando OFFLINE: solo boletos desde sucursal.\nCuando ONLINE: boletos desde cualquier origen.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade900,
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