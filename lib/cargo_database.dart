import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class CargoDatabase {
  // Almacena información de recibos de carga
  static Future<void> saveCargoReceipt(
      String destinatario,
      String remitente,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      String comprobante,
      Uint8List pdfData,
      String tipo,
      String destino) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cargoDir = Directory('${directory.path}/cargo_receipts');

      // Crear directorio si no existe
      if (!await cargoDir.exists()) {
        await cargoDir.create(recursive: true);
      }

      // Crear nombre de archivo usando fecha actual y número de comprobante
      String currentDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String filename = '${currentDate}_${comprobante}_${tipo}.pdf';

      // Guardar archivo PDF
      final file = File('${cargoDir.path}/$filename');
      await file.writeAsBytes(pdfData);

      // Guardar metadatos para ayudar en la búsqueda y visualización
      await _saveMetadata(
          destinatario,
          remitente,
          articulo,
          precio,
          telefonoDest,
          telefonoRemit,
          comprobante,
          currentDate,
          filename,
          tipo,
          destino
      );

      // Eliminar recibos antiguos
      await _cleanOldReceipts();
    } catch (e) {
      print('Error saving cargo receipt: $e');
    }
  }

  // Guardar metadatos para facilitar la búsqueda y visualización
  static Future<void> _saveMetadata(
      String destinatario,
      String remitente,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      String comprobante,
      String currentDate,
      String filename,
      String tipo,
      String destino) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final metadataFile = File('${directory.path}/cargo_receipts/metadata.json');

      // Crear o leer metadatos existentes
      Map<String, dynamic> metadata = {};
      if (await metadataFile.exists()) {
        String content = await metadataFile.readAsString();
        metadata = json.decode(content);
      }

      // Añadir nueva entrada
      if (!metadata.containsKey('receipts')) {
        metadata['receipts'] = [];
      }

      metadata['receipts'].add({
        'destinatario': destinatario,
        'remitente': remitente,
        'articulo': articulo,
        'precio': precio,
        'telefonoDest': telefonoDest,
        'telefonoRemit': telefonoRemit,
        'comprobante': comprobante,
        'date': currentDate,
        'time': DateFormat('HH:mm:ss').format(DateTime.now()),
        'filename': filename,
        'tipo': tipo,
        'destino': destino,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });

      // Guardar metadatos actualizados
      await metadataFile.writeAsString(json.encode(metadata));
    } catch (e) {
      print('Error saving metadata: $e');
    }
  }

  // Obtener lista de recibos de carga disponibles
  static Future<List<Map<String, dynamic>>> getCargoReceipts() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final metadataFile = File('${directory.path}/cargo_receipts/metadata.json');

      if (!await metadataFile.exists()) {
        return [];
      }

      String content = await metadataFile.readAsString();
      Map<String, dynamic> metadata = json.decode(content);

      if (!metadata.containsKey('receipts')) {
        return [];
      }

      // Convertir a lista y ordenar por marca de tiempo (más reciente primero)
      List<Map<String, dynamic>> receipts = List<Map<String, dynamic>>.from(metadata['receipts']);
      receipts.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      return receipts;
    } catch (e) {
      print('Error getting cargo receipts: $e');
      return [];
    }
  }

  // Obtener archivo PDF para un recibo específico
  static Future<File?> getReceiptFile(String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cargo_receipts/$filename');

      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error getting receipt file: $e');
      return null;
    }
  }

  // Limpiar recibos más antiguos que 2 semanas
  static Future<void> _cleanOldReceipts() async {
    try {
      final twoWeeksAgo = DateTime.now().subtract(Duration(days: 14));
      final twoWeeksAgoTimestamp = twoWeeksAgo.millisecondsSinceEpoch;

      // Obtener metadatos
      final directory = await getApplicationDocumentsDirectory();
      final metadataFile = File('${directory.path}/cargo_receipts/metadata.json');

      if (!await metadataFile.exists()) {
        return;
      }

      String content = await metadataFile.readAsString();
      Map<String, dynamic> metadata = json.decode(content);

      if (!metadata.containsKey('receipts')) {
        return;
      }

      // Filtrar recibos antiguos y recopilar nombres de archivo a eliminar
      List<dynamic> oldReceipts = [];
      List<dynamic> currentReceipts = [];

      for (var receipt in metadata['receipts']) {
        if (receipt['timestamp'] < twoWeeksAgoTimestamp) {
          oldReceipts.add(receipt);
        } else {
          currentReceipts.add(receipt);
        }
      }

      // Eliminar archivos antiguos
      for (var receipt in oldReceipts) {
        final file = File('${directory.path}/cargo_receipts/${receipt['filename']}');
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Actualizar metadatos con solo los recibos actuales
      metadata['receipts'] = currentReceipts;
      await metadataFile.writeAsString(json.encode(metadata));

    } catch (e) {
      print('Error cleaning old receipts: $e');
    }
  }

  // Obtener destinos únicos de la base de datos
  static Future<List<String>> getUniqueDestinations() async {
    try {
      final receipts = await getCargoReceipts();
      final Set<String> destinations = {};

      for (var receipt in receipts) {
        if (receipt.containsKey('destino') && receipt['destino'] != null) {
          destinations.add(receipt['destino'] as String);
        }
      }

      return destinations.toList();
    } catch (e) {
      print('Error getting unique destinations: $e');
      return [];
    }
  }

  // Filtrar recibos por destino
  static Future<List<Map<String, dynamic>>> getReceiptsByDestination(String destino) async {
    try {
      final receipts = await getCargoReceipts();

      return receipts.where((receipt) =>
      receipt.containsKey('destino') &&
          receipt['destino'] == destino
      ).toList();
    } catch (e) {
      print('Error filtering receipts by destination: $e');
      return [];
    }
  }

  // Buscar recibos por texto
  static Future<List<Map<String, dynamic>>> searchReceipts(String query) async {
    try {
      final receipts = await getCargoReceipts();
      final lowerQuery = query.toLowerCase();

      return receipts.where((receipt) =>
      (receipt['destinatario'].toString().toLowerCase().contains(lowerQuery)) ||
          (receipt['remitente'].toString().toLowerCase().contains(lowerQuery)) ||
          (receipt['articulo'].toString().toLowerCase().contains(lowerQuery)) ||
          (receipt['comprobante'].toString().toLowerCase().contains(lowerQuery))
      ).toList();
    } catch (e) {
      print('Error searching receipts: $e');
      return [];
    }
  }
}