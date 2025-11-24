import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../models/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GestionAnulacionesScreen extends StatefulWidget {
  @override
  _GestionAnulacionesScreenState createState() => _GestionAnulacionesScreenState();
}

class _GestionAnulacionesScreenState extends State<GestionAnulacionesScreen> {
  bool _cargando = true;
  List<Map<String, dynamic>> _usuarios = [];
  Map<String, int> _contadoresAnulaciones = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
    });

    try {
      final appDb = AppDatabase.instance;
      final usuarios = await appDb.getAllUsuarios();

      // Filtrar solo secretarias activas
      final secretarias = usuarios.where((u) =>
        u['rol'] == 'Secretaria' && u['activo'] == 1
      ).toList();

      // Obtener contador de anulaciones para cada secretaria
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final contadores = <String, int>{};

      for (var usuario in secretarias) {
        final username = usuario['username'] as String;
        final contador = await appDb.contarAnulacionesUsuario(username, hoy);
        contadores[username] = contador;
      }

      setState(() {
        _usuarios = secretarias;
        _contadoresAnulaciones = contadores;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
      setState(() {
        _cargando = false;
      });
      _mostrarMensaje('Error al cargar datos: $e', error: true);
    }
  }

  Future<void> _reiniciarContador(String username) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Confirmar Reinicio'),
          ],
        ),
        content: Text(
          '¿Está seguro de reiniciar el contador de anulaciones de $username?\n\n'
          'Esto permitirá que el usuario realice hasta 6 anulaciones nuevamente el día de hoy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('REINICIAR'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        // Guardar en SharedPreferences la lista de usuarios con contador reiniciado
        final prefs = await SharedPreferences.getInstance();
        final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final key = 'contadores_reiniciados_$hoy';

        List<String> reiniciados = prefs.getStringList(key) ?? [];
        if (!reiniciados.contains(username)) {
          reiniciados.add(username);
          await prefs.setStringList(key, reiniciados);
        }

        _mostrarMensaje(
          'Contador de anulaciones reiniciado para $username',
          success: true,
        );

        // Recargar datos
        await _cargarDatos();
      } catch (e) {
        _mostrarMensaje('Error al reiniciar contador: $e', error: true);
      }
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
    final authProvider = Provider.of<AuthProvider>(context);

    // Solo administradores pueden acceder
    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Acceso Denegado'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Solo administradores pueden acceder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.manage_accounts, size: 28),
            SizedBox(width: 12),
            Text('Gestión de Anulaciones'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade50.withOpacity(0.3),
                    Colors.white,
                  ],
                ),
              ),
              child: RefreshIndicator(
                onRefresh: _cargarDatos,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Información general
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Control de Anulaciones',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              '• Las secretarias pueden realizar hasta 6 anulaciones por día\n'
                              '• Después de 6 anulaciones, necesitan código de administrador\n'
                              '• Puede reiniciar el contador de un usuario si es necesario\n'
                              '• Los boletos solo se pueden anular si faltan más de 4 horas para la salida',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Lista de secretarias
                      Text(
                        'Secretarias (${_usuarios.length})',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 16),

                      if (_usuarios.isEmpty)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No hay secretarias registradas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._usuarios.map((usuario) {
                          final username = usuario['username'] as String;
                          final idSecretario = usuario['id_secretario'] as String? ?? 'N/A';
                          final sucursal = usuario['sucursal_origen'] as String? ?? 'N/A';
                          final contador = _contadoresAnulaciones[username] ?? 0;
                          final limiteAlcanzado = contador >= 6;

                          return Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: limiteAlcanzado ? Colors.red.shade300 : Colors.grey.shade300,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
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
                                        color: limiteAlcanzado
                                            ? Colors.red.shade100
                                            : Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: limiteAlcanzado
                                            ? Colors.red.shade700
                                            : Colors.blue.shade700,
                                        size: 32,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            username,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.badge, size: 16, color: Colors.grey.shade600),
                                              SizedBox(width: 4),
                                              Text(
                                                'ID: $idSecretario',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                                              SizedBox(width: 4),
                                              Text(
                                                sucursal,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: limiteAlcanzado
                                            ? Colors.red.shade100
                                            : (contador >= 4 ? Colors.orange.shade100 : Colors.green.shade100),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$contador / 6',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: limiteAlcanzado
                                              ? Colors.red.shade700
                                              : (contador >= 4 ? Colors.orange.shade700 : Colors.green.shade700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Divider(),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        limiteAlcanzado
                                            ? 'Límite alcanzado - Requiere código admin'
                                            : 'Anulaciones disponibles: ${6 - contador}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: limiteAlcanzado ? Colors.red.shade700 : Colors.grey.shade700,
                                          fontWeight: limiteAlcanzado ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: contador > 0 ? () => _reiniciarContador(username) : null,
                                      icon: Icon(Icons.refresh, size: 20),
                                      label: Text('Reiniciar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                      SizedBox(height: 24),

                      // Botón de actualizar
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _cargarDatos,
                          icon: Icon(Icons.refresh),
                          label: Text(
                            'ACTUALIZAR DATOS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
