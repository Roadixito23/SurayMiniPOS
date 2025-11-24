import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import '../models/server_status_provider.dart';
import '../models/auth_provider.dart';
import '../database/caja_database.dart';
import '../database/app_database.dart';
import '../models/comprobante.dart';
import '../models/tarifa.dart';

/// Ventana emergente consolidada de debug
/// Muestra todas las herramientas de debug en un solo lugar
class DebugPopup extends StatefulWidget {
  const DebugPopup({Key? key}) : super(key: key);

  @override
  _DebugPopupState createState() => _DebugPopupState();

  /// Método estático para mostrar el popup desde cualquier parte del programa
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DebugPopup(),
    );
  }
}

class _DebugPopupState extends State<DebugPopup> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final serverStatus = Provider.of<ServerStatusProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.orange.shade400],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panel de Desarrollo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Herramientas de prueba y simulación',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sección: Simulación de Conectividad
                    _buildSectionTitle('Simulación de Conectividad'),
                    SizedBox(height: 12),
                    _buildServerStatusCard(serverStatus),
                    SizedBox(height: 24),

                    // Sección: Base de Datos
                    _buildSectionTitle('Base de Datos de Prueba'),
                    SizedBox(height: 12),
                    _buildDatabaseActionsCard(),
                    SizedBox(height: 24),

                    // Sección: Información del Sistema
                    _buildSectionTitle('Información del Sistema'),
                    SizedBox(height: 12),
                    _buildSystemInfoCard(authProvider),
                    SizedBox(height: 12),

                    // Advertencia
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este panel es solo para desarrollo y pruebas. Los cambios pueden afectar los datos del sistema.',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildServerStatusCard(ServerStatusProvider serverStatus) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: serverStatus.isSimulated
            ? (serverStatus.isOnline ? Colors.green.shade50 : Colors.red.shade50)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: serverStatus.isSimulated
              ? (serverStatus.isOnline ? Colors.green.shade300 : Colors.red.shade300)
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(serverStatus.statusColor),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(serverStatus.statusColor).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado del Servidor',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      serverStatus.statusMessageWithSimulation,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(height: 1),
          SizedBox(height: 12),
          SwitchListTile(
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
                        value ? 'Servidor simulado: ONLINE' : 'Servidor simulado: OFFLINE',
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
                  size: 20,
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
            contentPadding: EdgeInsets.zero,
          ),
          if (serverStatus.isSimulated) ...[
            SizedBox(height: 8),
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
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OFFLINE: solo boletos desde sucursal local.\nONLINE: boletos desde cualquier origen.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseActionsCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Acciones de Base de Datos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Genera datos de prueba o limpia la base de datos para testing.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _poblarBaseDatos,
            icon: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.add_circle),
            label: Text(_isLoading ? 'Poblando...' : 'Poblar Base de Datos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _limpiarBaseDatos,
            icon: Icon(Icons.delete_forever),
            label: Text('Limpiar Base de Datos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red),
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard(AuthProvider authProvider) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Usuario', authProvider.username),
          Divider(height: 16, thickness: 1),
          _buildInfoRow('Rol', authProvider.rol),
          Divider(height: 16, thickness: 1),
          _buildInfoRow('ID Secretario', authProvider.idSecretario.toString()),
          Divider(height: 16, thickness: 1),
          _buildInfoRow('Sucursal', authProvider.sucursalActual ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Future<void> _poblarBaseDatos() async {
    try {
      // Mostrar diálogo de confirmación
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 12),
              Text('Poblar Base de Datos'),
            ],
          ),
          content: Text(
              '¿Está seguro de agregar datos de simulación? Esto generará ~100 ventas y gastos ficticios para el día de hoy.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('CONFIRMAR'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      setState(() => _isLoading = true);

      final cajaDb = CajaDatabase();
      final appDb = AppDatabase.instance;
      final comprobanteManager = ComprobanteManager();
      await comprobanteManager.initialize();
      final random = Random();

      final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String tipoDiaHoy =
          DateTime.now().weekday >= 6 ? 'DOMINGO / FERIADO' : 'LUNES A SÁBADO';

      // Obtener tarifas disponibles para hoy
      final tarifasMap = await appDb.getTarifasByTipoDia(tipoDiaHoy);
      final tarifas = tarifasMap.map((t) => Tarifa.fromMap(t)).toList();

      if (tarifas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No hay tarifas configuradas para poblar datos.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final List<String> horariosSalida = [
        '08:30',
        '09:45',
        '11:00',
        '12:00',
        '14:10',
        '15:40',
        '17:00',
        '19:50'
      ];
      final List<String> destinos = ['Aysen', 'Coyhaique'];
      final List<String> nombres = [
        'Ana',
        'Bruno',
        'Carla',
        'David',
        'Elena',
        'Felipe',
        'Gala',
        'Hugo',
        'Ines',
        'Juan'
      ];

      // 1. Poblar Ventas de Bus (80 ventas)
      int ventasBusGeneradas = 0;
      for (int i = 0; i < 80; i++) {
        final tarifa = tarifas[random.nextInt(tarifas.length)];
        if (tarifa.categoria.toUpperCase().contains('INTERMEDIO')) continue;

        final horario = horariosSalida[random.nextInt(horariosSalida.length)];
        final destino = destinos[random.nextInt(destinos.length)];
        final asiento = random.nextInt(45) + 1;
        final esEfectivo = random.nextBool();
        final valor = tarifa.valor;

        final String numeroComprobante =
            await comprobanteManager.getNextBusComprobante(tarifa.categoria);

        await cajaDb.registrarVentaBus(
          destino: destino,
          horario: horario,
          asiento: asiento.toString().padLeft(2, '0'),
          valor: valor,
          comprobante: numeroComprobante,
          tipoBoleto: tarifa.categoria,
          metodoPago: esEfectivo ? 'Efectivo' : 'Tarjeta',
          montoEfectivo: esEfectivo ? valor : 0,
          montoTarjeta: esEfectivo ? 0 : valor,
        );

        final salidaId = await appDb.crearObtenerSalida(
          fecha: fechaHoy,
          horario: horario,
          destino: destino,
          tipoDia: tipoDiaHoy,
        );

        try {
          await appDb.reservarAsiento(
            salidaId: salidaId,
            numeroAsiento: asiento,
            comprobante: numeroComprobante,
          );
        } catch (e) {
          // Ignorar error de asiento duplicado
        }
        ventasBusGeneradas++;
      }

      // 2. Poblar Ventas de Carga (15 ventas)
      for (int i = 0; i < 15; i++) {
        final String numeroComprobante =
            await comprobanteManager.getNextCargoComprobante();
        final valor = (random.nextInt(20) + 5) * 1000.0;
        await cajaDb.registrarVentaCargo(
          remitente:
              '${nombres[random.nextInt(nombres.length)]} ${nombres[random.nextInt(nombres.length)]}',
          destinatario:
              '${nombres[random.nextInt(nombres.length)]} ${nombres[random.nextInt(nombres.length)]}',
          destino: destinos[random.nextInt(destinos.length)],
          articulo: 'Caja N°${random.nextInt(100)}',
          valor: valor,
          comprobante: numeroComprobante,
          metodoPago: 'Efectivo',
          montoEfectivo: valor,
          montoTarjeta: 0,
        );
      }

      // 3. Poblar Gastos (2 gastos)
      await cajaDb.registrarGasto(
        tipoGasto: 'Combustible',
        monto: 75000.0,
        numeroMaquina: 'AB-123',
        chofer: 'Juan Perez',
      );
      await cajaDb.registrarGasto(
        tipoGasto: 'Otros',
        monto: 15000.0,
        descripcion: 'Insumos oficina',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Base de datos poblada con $ventasBusGeneradas ventas de bus, 15 de carga y 2 gastos.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al poblar base de datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _limpiarBaseDatos() async {
    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red),
              SizedBox(width: 12),
              Text('Limpiar Base de Datos'),
            ],
          ),
          content: Text(
            '¿Está COMPLETAMENTE SEGURO de eliminar TODOS los datos?\n\nEsta acción NO se puede deshacer.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('ELIMINAR TODO'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      setState(() => _isLoading = true);

      final db = AppDatabase.instance;
      await db.limpiarTodasLasTablas();

      final cajaDb = CajaDatabase();
      await cajaDb.limpiarDatos();

      await ComprobanteManager().resetCounter();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Base de datos limpiada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al limpiar base de datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
