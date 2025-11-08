import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../database/cargo_database.dart';
import '../models/comprobante.dart';
import '../database/caja_database.dart';
import 'pdf_optimizer.dart';

class CargoTicketGenerator {
  // Formato estandarizado para tickets de carga (térmico)
  static final PdfPageFormat ticketFormat = PdfPageFormat(
    58 * PdfPageFormat.mm,
    double.infinity,
  );

  // Formateador para precios en CLP
  static final _priceFormatter = NumberFormat('#,##0', 'es_CL');

  // Configuración para el rectángulo de cinta
  static final double tapeRectangleHeight = 45.0;

  // Optimizador de PDF para mejorar el rendimiento
  static final PdfOptimizer _optimizer = PdfOptimizer();
  static bool _resourcesLoaded = false;

  // Precargar recursos
  static Future<void> preloadResources() async {
    if (!_resourcesLoaded) {
      await _optimizer.preloadResources();
      _resourcesLoaded = true;
    }
  }

  /// Genera e imprime dos PDFs separados: copia cliente y copia carga (inspector)
  static Future<void> generateAndPrintTicket({
    required String destinatario,
    required String remitente,
    required String destino,
    required String articulo,
    required double valor,
    String? telefonoDest = '',
    String? telefonoRemit = '',
  }) async {
    try {
      // Asegurar que los recursos estén precargados
      await preloadResources();

      final comprobanteManager = ComprobanteManager();
      final numeroComprobante = await comprobanteManager.getNextCargoComprobante();

      final now = DateTime.now();
      final currentDate = DateFormat('dd/MM/yyyy').format(now);
      final currentTime = DateFormat('HH:mm:ss').format(now);

      // COPIA CLIENTE
      final clientPdf = await _generateClientPdf(
        remitente,
        destinatario,
        destino,
        articulo,
        valor,
        telefonoDest ?? '',
        telefonoRemit ?? '',
        currentDate,
        currentTime,
        numeroComprobante,
        false,
      );

      await CargoDatabase.saveCargoReceipt(
        destinatario,
        remitente,
        articulo,
        valor,
        telefonoDest ?? '',
        telefonoRemit ?? '',
        numeroComprobante,
        clientPdf,
        'Cliente',
        destino,
      );

      await Printing.layoutPdf(onLayout: (_) async => clientPdf, format: ticketFormat);

      // COPIA INSPECTOR (CARGA)
      final cargaPdf = await _generateCargaPdf(
        remitente,
        destinatario,
        destino,
        articulo,
        valor,
        telefonoDest ?? '',
        telefonoRemit ?? '',
        currentDate,
        currentTime,
        numeroComprobante,
        false,
      );

      await CargoDatabase.saveCargoReceipt(
        destinatario,
        remitente,
        articulo,
        valor,
        telefonoDest ?? '',
        telefonoRemit ?? '',
        numeroComprobante,
        cargaPdf,
        'Inspector',
        destino,
      );

      await Printing.layoutPdf(onLayout: (_) async => cargaPdf, format: ticketFormat);

      // Registrar en caja
      final cajaDb = CajaDatabase();
      await cajaDb.registrarVentaCargo(
        remitente: remitente,
        destinatario: destinatario,
        destino: destino,
        articulo: articulo,
        valor: valor,
        comprobante: numeroComprobante,
      );
    } catch (e) {
      debugPrint('Error al generar ticket: $e');
      // Limpiar caché en caso de error
      _optimizer.clearCache();
      throw e;
    }
  }

  /// Reimpresión: usa comprobante existente, permite elegir copias
  static Future<void> reprintTicket({
    required String tipo,
    required String comprobante,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Asegurar que los recursos estén precargados
      await preloadResources();

      final remitente = data['remitente'] ?? '';
      final destinatario = data['destinatario'] ?? '';
      final destino = data['destino'] ?? '';
      final articulo = data['articulo'] ?? '';
      final valor = data['precio'] is double ? data['precio'] : double.parse(data['precio'].toString());
      final telefonoDest = data['telefonoDest'] ?? '';
      final telefonoRemit = data['telefonoRemit'] ?? '';
      final originalDate = data['date'] ?? DateFormat('dd/MM/yyyy').format(DateTime.now());
      final originalTime = data['time'] ?? DateFormat('HH:mm:ss').format(DateTime.now());

      if (tipo == 'Cliente') {
        final clientPdf = await _generateClientPdf(
          remitente,
          destinatario,
          destino,
          articulo,
          valor,
          telefonoDest,
          telefonoRemit,
          originalDate,
          originalTime,
          comprobante,
          true,
        );
        await Printing.layoutPdf(onLayout: (_) async => clientPdf, format: ticketFormat);
      } else {
        final cargaPdf = await _generateCargaPdf(
          remitente,
          destinatario,
          destino,
          articulo,
          valor,
          telefonoDest,
          telefonoRemit,
          originalDate,
          originalTime,
          comprobante,
          true,
        );
        await Printing.layoutPdf(onLayout: (_) async => cargaPdf, format: ticketFormat);
      }
    } catch (e) {
      debugPrint('Error al reimprimir ticket: $e');
      // Limpiar caché en caso de error
      _optimizer.clearCache();
      throw e;
    }
  }

  // Widget para el rectángulo de cinta adhesiva
  static pw.Widget _buildTapeRectangle() {
    return pw.Container(
      width: double.infinity,
      height: tapeRectangleHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 4, color: PdfColors.black),
      ),
      child: pw.Center(
        child: pw.Text(
          'COLOCAR CINTA',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Widget para el box de información de entrega
  static pw.Widget _buildDeliveryInfoBox() {
    return pw.Container(
      padding: pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('Entregado el día: ', style: pw.TextStyle(fontSize: 10)),
              pw.Text('____', style: pw.TextStyle(fontSize: 10)),
              pw.Text('/', style: pw.TextStyle(fontSize: 10)),
              pw.Text('____', style: pw.TextStyle(fontSize: 10)),
              pw.Text('/', style: pw.TextStyle(fontSize: 10)),
              pw.Text('________', style: pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text('A las: ', style: pw.TextStyle(fontSize: 10)),
              pw.Text('____', style: pw.TextStyle(fontSize: 10)),
              pw.Text(' : ', style: pw.TextStyle(fontSize: 10)),
                pw.Text('____', style: pw.TextStyle(fontSize: 10)),
              pw.Text(' Hrs.', style: pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // Genera el PDF para Copia Cliente
  static Future<Uint8List> _generateClientPdf(
      String remitente,
      String destinatario,
      String destino,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      String fecha,
      String hora,
      String numeroComprobante,
      bool isReprint,
      ) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado: Logo + Comprobante
              _buildHeader(numeroComprobante),

              pw.SizedBox(height: 4),

              // Marca de reimpresión si aplica
              if (isReprint)
                pw.Center(
                  child: pw.Container(
                    color: PdfColors.grey200,
                    padding: pw.EdgeInsets.all(4),
                    margin: pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      'COPIA CLIENTE (REIMPRESIÓN)',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                    ),
                  ),
                )
              else
                pw.Center(
                  child: pw.Text(
                    'COPIA CLIENTE',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),

              pw.SizedBox(height: 8),

              // Contenido principal
              _buildContent(
                destinatario,
                articulo,
                precio,
                destino,
                telefonoDest,
                remitente,
                telefonoRemit,
                fecha,
                hora,
              ),

              pw.SizedBox(height: 6),

              // Pie de página
              pw.Center(child: pw.Image(_optimizer.getEndImage(), width: ticketFormat.width * 0.8)),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  // Genera el PDF para Copia Carga (Inspector)
  static Future<Uint8List> _generateCargaPdf(
      String remitente,
      String destinatario,
      String destino,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      String fecha,
      String hora,
      String numeroComprobante,
      bool isReprint,
      ) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Rectángulo para cinta adhesiva en la parte superior
              _buildTapeRectangle(),

              pw.SizedBox(height: 8),

              // Encabezado: Logo + Comprobante
              _buildHeader(numeroComprobante),

              pw.SizedBox(height: 4),

              // Marca de reimpresión si aplica
              if (isReprint)
                pw.Center(
                  child: pw.Container(
                    color: PdfColors.grey200,
                    padding: pw.EdgeInsets.all(4),
                    margin: pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      'COPIA CARGA (REIMPRESIÓN)',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                    ),
                  ),
                )
              else
                pw.Center(
                  child: pw.Text(
                    'COPIA CARGA',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),

              pw.SizedBox(height: 8),

              // Contenido principal
              _buildContent(
                destinatario,
                articulo,
                precio,
                destino,
                telefonoDest,
                remitente,
                telefonoRemit,
                fecha,
                hora,
              ),

              pw.SizedBox(height: 12),

              // Agregar imagen de fin ANTES de la línea de corte
              pw.Center(child: pw.Image(_optimizer.getEndImage(), width: ticketFormat.width * 0.8)),

              pw.SizedBox(height: 8),

              // Rectángulo para cinta adhesiva ANTES de la línea de corte
              _buildTapeRectangle(),

              pw.SizedBox(height: 8),

              // Línea de separación con tijeras
              _buildScissorsLine(),

              pw.SizedBox(height: 12),

              // Control Interno
              pw.Center(
                child: pw.Text(
                  'CONTROL INTERNO',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),

              pw.SizedBox(height: 4),

              _buildControlInternoBox(numeroComprobante, articulo, precio, fecha),

              pw.SizedBox(height: 8),

              // Nuevo box para información de entrega
              _buildDeliveryInfoBox(),

              pw.SizedBox(height: 69),

              pw.Container(width: double.infinity, height: 2, color: PdfColors.black),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  // Widget para el encabezado del ticket
  static pw.Widget _buildHeader(String ticketId) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: ticketFormat.width * 0.4,
          child: pw.Image(_optimizer.getLogoImage()),
        ),
        pw.Spacer(),
        pw.Container(
          width: ticketFormat.width * 0.5,
          padding: pw.EdgeInsets.all(2),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'COMPROBANTE DE CARGO',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'N° $ticketId',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget para el contenido principal del ticket
  static pw.Widget _buildContent(
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      String remitente,
      String telefonoRemit,
      String fecha,
      String hora,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          padding: pw.EdgeInsets.all(6),
          child: pw.Row(
            children: [
              pw.Text('Destino:', style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 4),
              pw.Text(
                destino,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 6),

        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          padding: pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Artículo:', style: pw.TextStyle(fontSize: 10)),
              pw.Text(
                articulo,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 6),

        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          padding: pw.EdgeInsets.all(6),
          child: pw.Row(
            children: [
              pw.Text('Precio:', style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 4),
              pw.Text(
                '\$${_priceFormatter.format(precio)}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 6),

        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          padding: pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Destinatario:', style: pw.TextStyle(fontSize: 10)),
              pw.Text(
                destinatario,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),

        if (telefonoDest.isNotEmpty) pw.SizedBox(height: 6),

        if (telefonoDest.isNotEmpty)
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            padding: pw.EdgeInsets.all(6),
            child: pw.Row(
              children: [
                pw.Text('Teléfono Dest.:', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(width: 4),
                pw.Text(
                  telefonoDest,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),

        pw.SizedBox(height: 6),

        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          padding: pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Remitente:', style: pw.TextStyle(fontSize: 10)),
              pw.Text(
                remitente,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),

        if (telefonoRemit.isNotEmpty) pw.SizedBox(height: 6),

        if (telefonoRemit.isNotEmpty)
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            padding: pw.EdgeInsets.all(6),
            child: pw.Row(
              children: [
                pw.Text('Teléfono Remit.:', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(width: 4),
                pw.Text(
                  telefonoRemit,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),

        pw.SizedBox(height: 6),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Fecha: $fecha', style: pw.TextStyle(fontSize: 8)),
            pw.Text('Hora: $hora', style: pw.TextStyle(fontSize: 8)),
          ],
        ),
      ],
    );
  }

  // Widget para la línea de corte con tijeras
  static pw.Widget _buildScissorsLine() {
    return pw.Row(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.only(right: 4),
          child: pw.Image(_optimizer.getTijeraImage(), width: 12),
        ),
        pw.Expanded(
          child: pw.Container(
            height: 0.5,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(
                  width: 0.5,
                  style: pw.BorderStyle.dashed,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget para el box de control interno - versión mejorada
  static pw.Widget _buildControlInternoBox(
      String ticketId,
      String articulo,
      double precio,
      String fechaDespacho,
      ) {
    return pw.Container(
      padding: pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 12),
          pw.Text('__________________________', style: pw.TextStyle(fontSize: 10)),
          pw.Text('Nombre', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.Text('__________________________', style: pw.TextStyle(fontSize: 10)),
          pw.Text('R.U.T.', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 16),
          pw.Text('___________________________', style: pw.TextStyle(fontSize: 10)),
          pw.Text('                 Firma', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 8),
          pw.Text(
            'Comprobante N° $ticketId',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Artículo: $articulo', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('Valor: \$${_priceFormatter.format(precio)}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Fecha: $fechaDespacho', style: pw.TextStyle(fontSize: 10)),
              pw.Text('Hora: ${DateFormat('HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}