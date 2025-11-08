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

    // Nuevos campos para métodos de pago y gastos
    final totalEfectivo = cierre['totalEfectivo'] ?? 0.0;
    final totalTarjeta = cierre['totalTarjeta'] ?? 0.0;
    final totalGastos = cierre['totalGastos'] ?? 0.0;
    final efectivoFinal = cierre['efectivoFinal'] ?? 0.0;
    final controlCaja = cierre['controlCaja'] as List<dynamic>?;
    final gastos = cierre['gastos'] as List<dynamic>?;

    doc.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        margin: pw.EdgeInsets.only(top: 25, left: 12, right: 6, bottom: 25),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
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

              // RESUMEN DE PAGOS
              pw.Divider(height: 1),
              pw.SizedBox(height: 5),

              pw.Text(
                'RESUMEN DE PAGOS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 5),

              _buildPaymentRow('Efectivo:', totalEfectivo),
              _buildPaymentRow('Tarjeta:', totalTarjeta),

              if (totalGastos > 0) ...[
                pw.Divider(height: 6),
                _buildPaymentRow('Gastos:', totalGastos, isNegative: true),
              ],

              pw.Divider(height: 6),

              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: efectivoFinal < 0 ? PdfColors.red100 : PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Efectivo Final:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '\$${_formatNumber(efectivoFinal)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: efectivoFinal < 0 ? PdfColors.red800 : PdfColors.green800,
                      ),
                    ),
                  ],
                ),
              ),

              // GASTOS
              if (gastos != null && gastos.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Divider(height: 1),
                pw.SizedBox(height: 5),

                pw.Text(
                  'GASTOS DEL DÍA',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 5),

                ...gastos.map((gasto) => _buildGastoItem(gasto)),
              ],

              // CONTROL DE CAJA
              if (controlCaja != null && controlCaja.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Divider(height: 1),
                pw.SizedBox(height: 5),

                pw.Text(
                  'CONTROL DE CAJA',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 5),

                // Encabezados
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          'Tipo',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Container(
                        width: 30,
                        child: pw.Text(
                          'Cant',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Subtotal',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),

                // Filas de datos
                ...controlCaja.map((item) => _buildControlCajaRow(item)),
              ],

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
                  textAlign: pw.TextAlign.center,
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
              pw.SizedBox(height: 10),
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
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Cantidad: $cantidad',
                  style: pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
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

  // Widget para mostrar fila de pago
  static pw.Widget _buildPaymentRow(String label, double amount, {bool isNegative = false}) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '\$${_formatNumber(amount)}',
            style: pw.TextStyle(
              fontSize: 9,
              color: isNegative ? PdfColors.red700 : PdfColors.black,
              fontWeight: isNegative ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar item de gasto
  static pw.Widget _buildGastoItem(Map<String, dynamic> gasto) {
    final tipoGasto = gasto['tipoGasto'] ?? '';
    final monto = gasto['monto'] ?? 0.0;
    final hora = gasto['hora'] ?? '';

    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 4),
      padding: pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5, color: PdfColors.red300),
        borderRadius: pw.BorderRadius.circular(3),
        color: PdfColors.red50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                tipoGasto,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '\$${_formatNumber(monto)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red800,
                ),
              ),
            ],
          ),
          if (tipoGasto == 'Combustible') ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'N° Máquina: ${gasto['numeroMaquina'] ?? ''}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
            pw.Text(
              'Chofer: ${gasto['chofer'] ?? ''}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ] else if (tipoGasto == 'Otros') ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Desc: ${gasto['descripcion'] ?? ''}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 2),
          pw.Text(
            'Hora: $hora',
            style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar fila de control de caja
  static pw.Widget _buildControlCajaRow(Map<String, dynamic> item) {
    final tipo = item['tipo'] ?? '';
    final cantidad = item['cantidad'] ?? 0;
    final subtotal = item['subtotal'] ?? 0.0;
    final primerComprobante = item['primerComprobante'] ?? '';
    final ultimoComprobante = item['ultimoComprobante'] ?? '';

    // Extraer solo el número final del comprobante
    String formatComprobante(String comprobante) {
      if (comprobante.isEmpty) return '';
      final parts = comprobante.split('-');
      return parts.length >= 3 ? parts[2] : comprobante;
    }

    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.3, color: PdfColors.grey300),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  tipo,
                  style: pw.TextStyle(fontSize: 7),
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              pw.Container(
                width: 30,
                child: pw.Text(
                  '$cantidad',
                  style: pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  '\$${_formatNumber(subtotal)}',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            'N°: ${formatComprobante(primerComprobante)} - ${formatComprobante(ultimoComprobante)}',
            style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
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