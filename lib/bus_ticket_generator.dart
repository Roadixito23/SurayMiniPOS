import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'comprobante.dart';

class BusTicketGenerator {
  // Formato estándar para impresoras térmicas de 58mm
  static final PdfPageFormat ticketFormat = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity);

  // Método principal para generar e imprimir el boleto
  static Future<void> generateAndPrintTicket({
    required String destino,
    required String asiento,
    required String horario,
    required String valor,
    bool isReprint = false,
    String? comprobanteManual,
  }) async {
    // Inicializar y obtener el gestor de comprobantes
    final ComprobanteManager comprobanteManager = ComprobanteManager();
    await comprobanteManager.initialize();

    // Obtener o generar el número de comprobante
    String numeroComprobante;

    if (isReprint && comprobanteManual != null) {
      // Si es reimpresión, usar el comprobante proporcionado
      numeroComprobante = comprobanteManual;
    } else {
      // Si es un nuevo ticket, incrementar el comprobante
      numeroComprobante = await comprobanteManager.incrementComprobante();

      // Registrar el comprobante en el log
      await comprobanteManager.logComprobante(
        tipo: 'BUS',
        descripcion: 'Destino: $destino, Asiento: $asiento',
        valor: double.tryParse(valor) ?? 0.0,
      );
    }

    // Generar PDF
    final Uint8List pdfData = await _generatePdf(
      destino: destino,
      asiento: asiento,
      horario: horario,
      valor: valor,
      numeroComprobante: numeroComprobante,
      isReprint: isReprint,
    );

    // Imprimir PDF
    await _printPdf(pdfData);

    // Guardar una copia local del PDF para reimprimir si es necesario
    if (!isReprint) {
      await _savePdfCopy(pdfData, numeroComprobante, 'bus');
    }
  }

  // Método para generar el PDF
  static Future<Uint8List> _generatePdf({
    required String destino,
    required String asiento,
    required String horario,
    required String valor,
    required String numeroComprobante,
    bool isReprint = false,
  }) async {
    final pw.Document doc = pw.Document();

    // Cargar logo e imágenes
    final pw.ImageProvider? logoImage = await _loadImageAsset('assets/logobkwt.png');
    final pw.ImageProvider? footerImage = await _loadImageAsset('assets/endTicket.png');

    // Obtener fecha y hora actual
    final String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final String currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

    // Añadir página con formato para impresora térmica
    doc.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Cabecera con logo y número de ticket
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo a la izquierda
                  logoImage != null
                      ? pw.Container(
                    width: ticketFormat.width * 0.5,
                    child: pw.Image(logoImage),
                  )
                      : pw.Container(),

                  // Número de ticket a la derecha
                  pw.Container(
                    width: ticketFormat.width * 0.45,
                    padding: pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1.5),
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'COMPROBANTE',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          numeroComprobante,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Marca de reimpresión si corresponde
              if (isReprint)
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    color: PdfColors.grey200,
                  ),
                  padding: pw.EdgeInsets.all(4),
                  margin: pw.EdgeInsets.only(bottom: 5),
                  child: pw.Text(
                    'REIMPRESIÓN',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red
                    ),
                  ),
                ),

              // Título del boleto
              pw.Text(
                'BOLETO DE VIAJE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 5),

              // Información principal del boleto
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                padding: pw.EdgeInsets.all(8),
                child: pw.Column(
                  children: [
                    _buildTicketDetailRow('Destino:', destino),
                    pw.SizedBox(height: 2),
                    _buildTicketDetailRow('Asiento:', asiento),
                    pw.SizedBox(height: 2),
                    _buildTicketDetailRow('Fecha:', currentDate),
                    pw.SizedBox(height: 2),
                    _buildTicketDetailRow('Hora:', horario),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Valor del boleto
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                padding: pw.EdgeInsets.all(8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'VALOR:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      '\$$valor',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 5),

              // Texto de validez
              pw.Text(
                'Válido sólo para la fecha y hora indicada',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 5),

              // Hora y fecha de emisión
              pw.Text(
                'Impreso: $currentDate $currentTime',
                style: pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),

              // Pie de página
              footerImage != null
                  ? pw.Image(footerImage)
                  : pw.Container(),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // Método para imprimir el PDF
  static Future<void> _printPdf(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      format: ticketFormat,
    );
  }

  // Método para guardar una copia local del PDF
  static Future<void> _savePdfCopy(
      Uint8List pdfData,
      String numeroComprobante,
      String tipo
      ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final pdfDirectory = Directory('${directory.path}/pdf_tickets');

      // Crear directorio si no existe
      if (!await pdfDirectory.exists()) {
        await pdfDirectory.create(recursive: true);
      }

      // Guardar el archivo con un nombre que incluya el número de comprobante
      final sanitizedComprobante = numeroComprobante.replaceAll('-', '_');
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '${tipo}_${sanitizedComprobante}_$timestamp.pdf';

      final file = File('${pdfDirectory.path}/$fileName');
      await file.writeAsBytes(pdfData);

      debugPrint('PDF guardado: ${file.path}');
    } catch (e) {
      debugPrint('Error al guardar copia del PDF: $e');
    }
  }

  // Método para crear filas de detalle en el ticket
  static pw.Widget _buildTicketDetailRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  // Método para cargar imágenes
  static Future<pw.ImageProvider?> _loadImageAsset(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error al cargar imagen: $e');
      return null;
    }
  }

  // Método para reimprimir un boleto específico
  static Future<void> reprintTicket(String comprobanteNumber) async {
    try {
      // Buscar el archivo PDF guardado
      final directory = await getApplicationDocumentsDirectory();
      final pdfDirectory = Directory('${directory.path}/pdf_tickets');

      if (await pdfDirectory.exists()) {
        final sanitizedComprobante = comprobanteNumber.replaceAll('-', '_');
        final files = await pdfDirectory
            .list()
            .where((entity) =>
        entity is File &&
            entity.path.contains(sanitizedComprobante))
            .toList();

        if (files.isNotEmpty) {
          // Tomar el archivo más reciente
          files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
          final pdfFile = files.first as File;

          // Reimprimir el PDF guardado
          final pdfData = await pdfFile.readAsBytes();
          await _printPdf(pdfData);

          debugPrint('Reimpresión exitosa: ${pdfFile.path}');
          return;
        }
      }

      throw Exception('No se encontró el comprobante para reimpresión');
    } catch (e) {
      debugPrint('Error al reimprimir: $e');
      rethrow;
    }
  }

  // Método para anular un boleto
  static Future<void> cancelTicket(String comprobanteNumber) async {
    // Inicializar y obtener el gestor de comprobantes
    final ComprobanteManager comprobanteManager = ComprobanteManager();
    await comprobanteManager.initialize();

    try {
      // Buscar el boleto original para obtener información
      final directory = await getApplicationDocumentsDirectory();
      final String logFilePath = '${directory.path}/comprobante_log.txt';
      final File logFile = File(logFilePath);

      if (await logFile.exists()) {
        final String logContent = await logFile.readAsString();
        final List<String> lines = logContent.split('\n');

        // Buscar la línea correspondiente al comprobante a anular
        for (String line in lines) {
          if (line.contains(comprobanteNumber)) {
            // Analizar la línea para extraer información
            final parts = line.split(', ');
            if (parts.length >= 5) {
              final tipo = parts[2];
              final descripcion = parts[3];
              final valor = double.tryParse(parts[4]) ?? 0.0;

              // Registrar la anulación en el log
              await comprobanteManager.logComprobante(
                tipo: 'ANULACION_$tipo',
                descripcion: 'ANULACIÓN: $descripcion',
                valor: valor,
                isAnulacion: true,
              );

              // Generar y guardar un PDF de anulación
              final Uint8List pdfData = await _generateCancellationPdf(
                comprobanteNumber: comprobanteNumber,
                descripcion: descripcion,
                valor: valor,
              );

              // Guardar copia del PDF de anulación
              await _savePdfCopy(pdfData, comprobanteNumber, 'anulacion');

              // Imprimir comprobante de anulación
              await _printPdf(pdfData);

              debugPrint('Anulación exitosa para el comprobante: $comprobanteNumber');
              return;
            }
          }
        }
      }

      throw Exception('No se encontró el comprobante para anular');
    } catch (e) {
      debugPrint('Error al anular boleto: $e');
      rethrow;
    }
  }

  // Método para generar PDF de anulación
  static Future<Uint8List> _generateCancellationPdf({
    required String comprobanteNumber,
    required String descripcion,
    required double valor,
  }) async {
    final pw.Document doc = pw.Document();

    // Cargar logo e imágenes
    final pw.ImageProvider? logoImage = await _loadImageAsset('assets/logobkwt.png');
    final pw.ImageProvider? footerImage = await _loadImageAsset('assets/endTicket.png');

    // Obtener fecha y hora actual
    final String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final String currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

    // Añadir página con formato para impresora térmica
    doc.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Cabecera con logo
              if (logoImage != null)
                pw.Container(
                  width: ticketFormat.width * 0.7,
                  child: pw.Image(logoImage),
                ),

              pw.SizedBox(height: 10),

              // Título de anulación
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.red),
                  color: PdfColors.red100,
                ),
                padding: pw.EdgeInsets.all(8),
                width: double.infinity,
                child: pw.Column(
                  children: [
                    pw.Text(
                      'ANULACIÓN',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Comprobante: $comprobanteNumber',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Detalles de la anulación
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                padding: pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Detalles:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      descripcion,
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Valor Anulado:',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          '-\$${valor.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Información de anulación
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                padding: pw.EdgeInsets.all(8),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Fecha de Anulación: $currentDate',
                      style: pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      'Hora de Anulación: $currentTime',
                      style: pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Campo para firma
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                height: 40,
                width: double.infinity,
                child: pw.Center(
                  child: pw.Text(
                    'Firma Autorizada',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 15),

              // Pie de página
              if (footerImage != null)
                pw.Image(footerImage),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // Método para obtener histórico de boletos
  static Future<List<Map<String, dynamic>>> getTicketHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String logFilePath = '${directory.path}/comprobante_log.txt';
      final File logFile = File(logFilePath);

      List<Map<String, dynamic>> tickets = [];

      if (await logFile.exists()) {
        final String logContent = await logFile.readAsString();
        final List<String> lines = logContent.split('\n');

        for (String line in lines) {
          if (line.trim().isEmpty) continue;

          final parts = line.split(', ');
          if (parts.length >= 5) {
            final Map<String, dynamic> ticket = {
              'fecha': parts[0],
              'comprobante': parts[1],
              'tipo': parts[2],
              'descripcion': parts[3],
              'valor': double.tryParse(parts[4]) ?? 0.0,
            };

            tickets.add(ticket);
          }
        }
      }

      // Ordenar por fecha descendente (más reciente primero)
      tickets.sort((a, b) => b['fecha'].compareTo(a['fecha']));

      return tickets;
    } catch (e) {
      debugPrint('Error al obtener historial: $e');
      return [];
    }
  }
}