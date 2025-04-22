import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class ComprobanteManager {
  // Valores por defecto y constantes
  static const String _fileName = 'comprobantes.json';
  int _comprobanteNumber = 1;
  int _ticketId = 1;
  bool _isInitialized = false;

  // Singleton pattern
  static final ComprobanteManager _instance = ComprobanteManager._internal();

  factory ComprobanteManager() {
    return _instance;
  }

  ComprobanteManager._internal();

  // Getters
  int get comprobanteNumber => _comprobanteNumber;
  int get ticketId => _ticketId;
  bool get isInitialized => _isInitialized;

  // Formatear el comprobante en formato XX-YYYYYY
  String get formattedComprobante {
    String formattedId = _ticketId.toString().padLeft(2, '0');
    return '$formattedId-${_comprobanteNumber.toString().padLeft(6, '0')}';
  }

  // Inicializar el administrador de comprobantes
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _loadComprobanteData();
      _isInitialized = true;
    }
  }

  // Obtener la ruta del archivo de comprobantes
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  // Cargar los datos de comprobantes desde el archivo local
  Future<void> _loadComprobanteData() async {
    try {
      final file = await _localFile;

      // Verificar si el archivo existe
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> data = json.decode(contents);

        _comprobanteNumber = data['comprobanteNumber'] ?? 1;
        _ticketId = data['ticketId'] ?? 1;

        debugPrint('Comprobante data loaded: ID=$_ticketId, Number=$_comprobanteNumber');
      } else {
        // Si el archivo no existe, guardar los valores por defecto
        await _saveComprobanteData();
        debugPrint('No comprobante file found, created with default values');
      }
    } catch (e) {
      debugPrint('Error loading comprobante data: $e');
      // Si hay un error, simplemente continuar con los valores por defecto
    }
  }

  // Guardar los datos de comprobantes en el archivo local
  Future<void> _saveComprobanteData() async {
    try {
      final file = await _localFile;
      final Map<String, dynamic> data = {
        'comprobanteNumber': _comprobanteNumber,
        'ticketId': _ticketId,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(json.encode(data));
      debugPrint('Comprobante data saved: ID=$_ticketId, Number=$_comprobanteNumber');
    } catch (e) {
      debugPrint('Error saving comprobante data: $e');
    }
  }

  // Incrementar el número de comprobante
  Future<String> incrementComprobante() async {
    _comprobanteNumber++;

    // Reiniciar si se excede el límite
    if (_comprobanteNumber > 999999) {
      _comprobanteNumber = 1;
    }

    await _saveComprobanteData();
    return formattedComprobante;
  }

  // Establecer el ID del dispositivo
  Future<void> setTicketId(int id) async {
    if (id >= 1 && id <= 99) {
      _ticketId = id;
      await _saveComprobanteData();
      debugPrint('Ticket ID updated to $_ticketId');
    } else {
      throw ArgumentError('Ticket ID must be between 1 and 99');
    }
  }

  // Reiniciar el contador de comprobantes
  Future<void> resetComprobante() async {
    _comprobanteNumber = 1;
    await _saveComprobanteData();
    debugPrint('Comprobante number reset to 1');
  }

  // Guardar registro de comprobante (para auditoría)
  Future<void> logComprobante({
    required String tipo,
    required String descripcion,
    required double valor,
    bool isAnulacion = false,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final File logFile = File('${directory.path}/comprobante_log.txt');

      final log = '${DateTime.now().toIso8601String()}, '
          '${formattedComprobante}, '
          '$tipo, '
          '$descripcion, '
          '${isAnulacion ? -valor : valor}\n';

      // Append al archivo de log
      await logFile.writeAsString(log, mode: FileMode.append);
    } catch (e) {
      debugPrint('Error logging comprobante: $e');
    }
  }
}