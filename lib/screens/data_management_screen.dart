import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/server_status_provider.dart';

/// Pantalla para monitorear el estado del servidor y soporte
class DataManagementScreen extends StatefulWidget {
  @override
  _DataManagementScreenState createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Animación de pulso para el indicador de estado
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverStatus = Provider.of<ServerStatusProvider>(context);
    final isOnline = serverStatus.isOnline;

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Datos'),
        centerTitle: true,
        backgroundColor: Color(0xFFB8A5D6), // Lila suave
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB8A5D6), // Lila suave
              Color(0xFFC5D5C5), // Verde salvia pastel
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Estado del servidor
              _buildServerStatusCard(isOnline, serverStatus),

              SizedBox(height: 24),

              // Información de estado
              _buildStatusInfoCard(isOnline),

              SizedBox(height: 24),

              // Soporte técnico
              _buildSupportCard(),

              SizedBox(height: 24),

              // Acciones rápidas (TODO: implementar más adelante)
              _buildQuickActionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerStatusCard(bool isOnline, ServerStatusProvider serverStatus) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isOnline
                ? [Color(0xFF4CAF50), Color(0xFF81C784)]
                : [Color(0xFFF44336), Color(0xFFE57373)],
          ),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOnline ? Icons.cloud_done : Icons.cloud_off,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            Text(
              isOnline ? 'SERVIDOR ONLINE' : 'SERVIDOR OFFLINE',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              isOnline
                  ? 'Sistema conectado y operativo'
                  : 'Sistema funcionando en modo local',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusInfoCard(bool isOnline) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFF6B4E9F),
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Estado Actual',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B4E9F),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.check_circle,
              'Ventas permitidas:',
              isOnline ? 'Desde cualquier origen' : 'Solo desde sucursal local',
              isOnline ? Colors.green : Colors.orange,
            ),
            SizedBox(height: 12),
            _buildInfoRow(
              Icons.sync,
              'Sincronización:',
              isOnline ? 'Activa en tiempo real' : 'En espera de conexión',
              isOnline ? Colors.green : Colors.grey,
            ),
            SizedBox(height: 12),
            _buildInfoRow(
              Icons.storage,
              'Almacenamiento:',
              isOnline ? 'Local y remoto' : 'Solo local',
              isOnline ? Colors.green : Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.support_agent,
                  color: Color(0xFF6B4E9F),
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Soporte Técnico',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B4E9F),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFB8A5D6), width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.email, color: Color(0xFF6B4E9F)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Correo de Soporte:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'dante@suray.cl',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B4E9F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, color: Color(0xFF6B4E9F)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: 'dante@suray.cl'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Correo copiado al portapapeles'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        tooltip: 'Copiar correo',
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Para recibir asistencia técnica o reportar problemas, contacte a través del correo electrónico indicado.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: Color(0xFF6B4E9F),
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Acciones Rápidas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B4E9F),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.construction, color: Colors.orange, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Funciones adicionales se implementarán próximamente',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
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
