import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'caja_database.dart';
import 'shared_widgets.dart';
import 'comprobante.dart';

/// Pantalla para gestionar los datos y backups de la aplicación
class DataManagementScreen extends StatefulWidget {
  @override
  _DataManagementScreenState createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  final CajaDatabase _cajaDatabase = CajaDatabase();
  final ComprobanteManager _comprobanteManager = ComprobanteManager();
  bool _isLoading = false;
  List<FileSystemEntity> _backupFiles = [];
  DateTime? _ultimaFechaBackup;
  String? _backupLocation;
  String? _exportLocation;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  /// Carga la lista de backups existentes
  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Inicializar la base de datos si es necesario
      await _cajaDatabase.initialize();

      // Obtener directorio de la aplicación
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/backups');

      if (await backupDir.exists()) {
        // Obtener lista de archivos en el directorio de backups
        _backupFiles = await backupDir.list().toList();

        // Ordenar por fecha (más reciente primero)
        _backupFiles.sort((a, b) => b.path.compareTo(a.path));

        // Obtener fecha del último backup
        if (_backupFiles.isNotEmpty) {
          final fileName = _backupFiles.first.path.split('/').last;
          final timestampStr = fileName.split('_').last.split('.').first;
          final timestamp = int.tryParse(timestampStr);
          if (timestamp != null) {
            _ultimaFechaBackup = DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
      }

      setState(() {
        _backupLocation = '${backupDir.path}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar backups: $e')),
      );
    }
  }

  /// Crea un nuevo backup manualmente
  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _cajaDatabase.crearBackup();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Recargar la lista de backups
        await _loadBackups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear backup'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear backup: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Restaura desde el backup más reciente
  Future<void> _restoreFromBackup() async {
    // Pedir confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: 'Confirmar Restauración',
        content: 'Esta acción restaurará los datos desde el backup más reciente. '
            'Los datos actuales serán reemplazados. ¿Desea continuar?',
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _cajaDatabase.restaurarDesdeBackup();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Datos restaurados exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo restaurar los datos'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al restaurar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Exporta todos los datos a un archivo externo
  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final exportPath = await _cajaDatabase.exportarDatos();

      setState(() {
        _exportLocation = exportPath;
      });

      if (exportPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Datos exportados a: $exportPath'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron exportar los datos'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Limpia todos los datos (para depuración)
  Future<void> _clearAllData() async {
    // Pedir confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ADVERTENCIA'),
        content: Text(
          '⚠️ Esta acción eliminará TODOS los datos de la aplicación:\n\n'
              '- Ventas pendientes\n'
              '- Historial de cierres\n'
              '- Contador de comprobantes\n\n'
              'Esta operación NO SE PUEDE DESHACER.\n\n'
              'Escriba "CONFIRMAR" para continuar:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sí, eliminar todo', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear backup antes de limpiar (por seguridad)
      await _cajaDatabase.crearBackup();

      // Limpiar datos de caja
      await _cajaDatabase.limpiarDatos();

      // Reiniciar contador de comprobantes
      await _comprobanteManager.resetCounter();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Todos los datos han sido eliminados. Se ha creado un backup automático.'),
          backgroundColor: Colors.green,
        ),
      );

      // Recargar la lista de backups
      await _loadBackups();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al limpiar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Datos'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Backup
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backup de Datos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Información del último backup
                    _buildInfoRow(
                      'Último backup:',
                      _ultimaFechaBackup != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(_ultimaFechaBackup!)
                          : 'No hay backups',
                    ),
                    _buildInfoRow(
                      'Ubicación:',
                      _backupLocation ?? 'No disponible',
                    ),
                    _buildInfoRow(
                      'Backups disponibles:',
                      '${_backupFiles.length}',
                    ),

                    SizedBox(height: 16),

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.backup),
                          label: Text('Crear Backup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          onPressed: _createBackup,
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.restore),
                          label: Text('Restaurar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                          ),
                          onPressed: _backupFiles.isEmpty ? null : _restoreFromBackup,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Sección de Exportación
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exportación de Datos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Explicación
                    Text(
                      'Exporte todos los datos para guardarlos en un dispositivo externo o transferirlos a otro equipo.',
                      style: TextStyle(fontSize: 14),
                    ),

                    if (_exportLocation != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Última exportación: $_exportLocation',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],

                    SizedBox(height: 16),

                    // Botón de exportación
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.file_download),
                        label: Text('Exportar Todos los Datos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: _exportData,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Sección de Eliminación de Datos (zona peligrosa)
            Card(
              elevation: 4,
              color: Colors.red.shade50,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zona Peligrosa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    SizedBox(height: 8),

                    Text(
                      '⚠️ Las siguientes acciones son irreversibles y pueden causar pérdida de datos.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Botón para limpiar todos los datos
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.delete_forever),
                        label: Text('Eliminar Todos los Datos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                        onPressed: _clearAllData,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}