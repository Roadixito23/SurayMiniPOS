import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class CierreCajaReportGenerator {
  // Usar el mismo formato que los tickets de bus y cargo
  static final PdfPageFormat ticketFormat = PdfPageFormat(
    58 * PdfPageFormat.mm,  // Ancho estándar para impresoras térmicas
    double.infinity,        // Altura flexible basada en el contenido
  );

  static Future<void> generateAndPrintReport(Map<String, dynamic> cierre) async {
    try {
      final pdfData = await _generatePdf(cierre);

      // Imprimir el reporte
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        format: ticketFormat,
      );
    } catch (e) {
      debugPrint('Error al generar reporte de cierre: $e');
      throw e;
    }
  }

  static Future<Uint8List> _generatePdf(Map<String, dynamic> cierre) async {
    final doc = pw.Document();

    // Cargar logo
    pw.ImageProvider? logoImage = await _loadImageAsset('assets/logocolorminipos.png');
    pw.ImageProvider? endImage = await _loadImageAsset('assets/endTicket.png');

    // Obtener datos del cierre
    final fecha = cierre['fecha'];
    final hora = cierre['hora'];
    final totalBus = cierre['totalBus'];
    final totalCargo = cierre['totalCargo'];
    final total = cierre['total'];
    final cantidadBus = cierre['cantidadBus'];
    final cantidadCargo = cierre['cantidadCargo'];
    final cantidad = cierre['cantidad'];
    final observaciones = cierre['observaciones'];

    // Destinos para resumen
    final destinosBus = cierre['destinosBus'] as Map<String, dynamic>?;
    final destinosCargo = cierre['destinosCargo'] as Map<String, dynamic>?;

    doc.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Cabecera con logo
              logoImage != null
                  ? pw.Image(logoImage, width: ticketFormat.width * 0.8)
                  : pw.SizedBox(),
              pw.SizedBox(height: 10),

              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text('Punto de Venta Express', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),

              // Título del reporte
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.symmetric(vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey800,
                ),
                child: pw.Text(
                  'CIERRE DE CAJA',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              pw.SizedBox(height: 10),

              // Información de fecha y hora
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Fecha: $fecha',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    'Hora: $hora',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),

              pw.SizedBox(height: 5),

              // Usuario
              pw.Text(
                'Secretario: 01',
                style: pw.TextStyle(fontSize: 10),
              ),

              pw.Divider(),

              // RESUMEN GENERAL
              pw.Text(
                'RESUMEN GENERAL',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 5),

              // Totales de Bus
              _buildSummarySection('BOLETOS DE BUS', cantidadBus, totalBus),

              pw.SizedBox(height: 5),

              // Totales de Cargo
              _buildSummarySection('CARGA', cantidadCargo, totalCargo),

              pw.SizedBox(height: 10),

              // Total general
              pw.Container(
                padding: pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'TOTAL GENERAL',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '\$${_formatNumber(total)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Ventas: $cantidad',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // RESUMEN POR DESTINO
              if (destinosBus != null && destinosBus.isNotEmpty ||
                  destinosCargo != null && destinosCargo.isNotEmpty) ...[
                pw.Divider(height: 1),

                pw.SizedBox(height: 5),

                pw.Text(
                  'RESUMEN POR DESTINO',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 5),

                // Destinos de Bus
                if (destinosBus != null && destinosBus.isNotEmpty) ...[
                  pw.Text(
                    'Bus:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  ...destinosBus.entries.map((entry) =>
                      _buildDestinoRow(entry.key, entry.value['cantidad'], entry.value['total']),
                  ),
                  pw.SizedBox(height: 5),
                ],

                // Destinos de Cargo
                if (destinosCargo != null && destinosCargo.isNotEmpty) ...[
                  pw.Text(
                    'Carga:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  ...destinosCargo.entries.map((entry) =>
                      _buildDestinoRow(entry.key, entry.value['cantidad'], entry.value['total']),
                  ),
                ],
              ],

              // Observaciones (si hay)
              if (observaciones != null && observaciones.isNotEmpty) ...[
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Text(
                  'OBSERVACIONES:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  observaciones,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],

              // Pie de página
              pw.SizedBox(height: 10),
              pw.Divider(height: 1),

              pw.SizedBox(height: 5),

              pw.Text(
                'Cierre realizado: ${DateTime.now().toString().substring(0, 19)}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
              ),

              // Línea de firma
              pw.SizedBox(height: 20),
              pw.Container(
                width: ticketFormat.width * 0.7,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 1),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Firma',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
              ),

              // Imagen de fin de ticket
              pw.SizedBox(height: 15),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // Widget para mostrar sección de resumen
  static pw.Widget _buildSummarySection(String title, int cantidad, double total) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: pw.EdgeInsets.all(6),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Cantidad: $cantidad',
                  style: pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          pw.Text(
            '\$${_formatNumber(total)}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar fila de destino
  static pw.Widget _buildDestinoRow(String destino, int cantidad, double total) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              destino,
              style: pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Container(
            width: 20,
            alignment: pw.Alignment.center,
            child: pw.Text(
              '$cantidad',
              style: pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              '\$${_formatNumber(total)}',
              style: pw.TextStyle(fontSize: 9),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Método para formatear números
  static String _formatNumber(dynamic number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  // Método para cargar imágenes desde los assets
  static Future<pw.ImageProvider?> _loadImageAsset(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error al cargar imagen "$assetPath": $e');
      return null;
    }
  }
}