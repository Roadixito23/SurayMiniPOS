import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'cargo_database.dart';
import 'comprobante.dart';
import 'caja_database.dart';

class CargoTicketGenerator {
  // Formato estandarizado para tickets de carga (térmico)
  static final PdfPageFormat ticketFormat = PdfPageFormat(
    58 * PdfPageFormat.mm,
    double.infinity,
  );

  // Formateador para precios en CLP
  static final _priceFormatter = NumberFormat('#,##0', 'es_CL');

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
      final comprobanteManager = ComprobanteManager();
      final numeroComprobante = await comprobanteManager.getNextCargoComprobante();

      final now = DateTime.now();
      final currentDate = DateFormat('dd/MM/yyyy').format(now);
      final currentTime = DateFormat('HH:mm:ss').format(now);

      final logo = await _loadImageAsset('assets/logobkwt.png');
      final endImage = await _loadImageAsset('assets/endTicket.png');
      final scissorsImage = await _loadImageAsset('assets/tijera.png');

      // COPIA CLIENTE
      final clientPdf = await _generateClientPdf(
        logo,
        endImage,
        scissorsImage,
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
        logo,
        endImage,
        scissorsImage,
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
      final logo = await _loadImageAsset('assets/logobkwt.png');
      final endImage = await _loadImageAsset('assets/endTicket.png');
      final scissorsImage = await _loadImageAsset('assets/tijera.png');

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
          logo,
          endImage,
          scissorsImage,
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
          logo,
          endImage,
          scissorsImage,
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
      throw e;
    }
  }

  // Genera el PDF para Copia Cliente
  static Future<Uint8List> _generateClientPdf(
      pw.ImageProvider? logo,
      pw.ImageProvider? endImage,
      pw.ImageProvider? scissorsImage,
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
              _buildHeader(logo, numeroComprobante),

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

              // Pie
              pw.Center(child: endImage != null ? pw.Image(endImage, width: ticketFormat.width * 0.8) : pw.Container()),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  // Genera el PDF para Copia Carga (Inspector)
  static Future<Uint8List> _generateCargaPdf(
      pw.ImageProvider? logo,
      pw.ImageProvider? endImage,
      pw.ImageProvider? scissorsImage,
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
              _buildHeader(logo, numeroComprobante),

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

              // Línea de separación con tijeras
              _buildScissorsLine(scissorsImage),

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
  static pw.Widget _buildHeader(pw.ImageProvider? logo, String ticketId) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: ticketFormat.width * 0.5,
          child: logo != null ? pw.Image(logo) : pw.Text('Buses Suray', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(
          width: ticketFormat.width * 0.5,
          padding: pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'COMPROBANTE DE CARGO',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'N° $ticketId',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
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
  static pw.Widget _buildScissorsLine(pw.ImageProvider? scissorsImage) {
    return pw.Row(
      children: [
        if (scissorsImage != null)
          pw.Padding(
            padding: pw.EdgeInsets.only(right: 4),
            child: pw.Image(scissorsImage, width: 12),
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

  // Widget para el box de control interno
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
          pw.Text(
            'N° $ticketId',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Nombre: __________________________', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('RUT: ____________________________', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('Firma: ___________________________', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text('Artículo: $articulo', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('Valor: \$${_priceFormatter.format(precio)}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('Fecha despacho: $fechaDespacho', style: pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  // Carga imágenes desde assets
  static Future<pw.ImageProvider?> _loadImageAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error al cargar imagen "$path": $e');
      return null;
    }
  }
}