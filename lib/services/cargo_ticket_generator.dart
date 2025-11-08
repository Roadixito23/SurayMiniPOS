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
  // Formato estandarizado para tickets de carga (térmico - 25% más pequeño)
  static final PdfPageFormat ticketFormat = PdfPageFormat(
    43.5 * PdfPageFormat.mm,
    double.infinity,
  );

  // Formateador para precios en CLP
  static final _priceFormatter = NumberFormat('#,##0', 'es_CL');

  // Configuración para el rectángulo de cinta (25% más pequeño)
  static final double tapeRectangleHeight = 34.0;

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
    String metodoPago = 'Efectivo', // Método de pago: "Efectivo", "Tarjeta", "Personalizar"
    double? montoEfectivo,          // Para método personalizado
    double? montoTarjeta,           // Para método personalizado
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

      // Registrar en caja con método de pago
      final cajaDb = CajaDatabase();
      await cajaDb.registrarVentaCargo(
        remitente: remitente,
        destinatario: destinatario,
        destino: destino,
        articulo: articulo,
        valor: valor,
        comprobante: numeroComprobante,
        metodoPago: metodoPago,
        montoEfectivo: montoEfectivo,
        montoTarjeta: montoTarjeta,
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
        border: pw.Border.all(width: 3, color: PdfColors.black),
      ),
      child: pw.Center(
        child: pw.Text(
          'COLOCAR CINTA',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Widget para el box de información de entrega
  static pw.Widget _buildDeliveryInfoBox() {
    return pw.Container(
      padding: pw.EdgeInsets.all(4.5),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('Entregado el día: ', style: pw.TextStyle(fontSize: 7.5)),
              pw.Text('____', style: pw.TextStyle(fontSize: 7.5)),
              pw.Text('/', style: pw.TextStyle(fontSize: 7.5)),
              pw.Text('____', style: pw.TextStyle(fontSize: 7.5)),
              pw.Text('/', style: pw.TextStyle(fontSize: 7.5)),
              pw.Text('________', style: pw.TextStyle(fontSize: 7.5)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Text('A las: ', style: pw.TextStyle(fontSize: 7.5)),
              pw.Text('____', style: pw.TextStyle(fontSize: 7.5)),
              pw.Text(' : ', style: pw.TextStyle(fontSize: 7.5)),
              pw.Text('____', style: pw.TextStyle(fontSize: 7.5)),
              pw.Text(' Hrs.', style: pw.TextStyle(fontSize: 7.5)),
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
        margin: pw.EdgeInsets.symmetric(vertical: 19, horizontal: 4.5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Encabezado: Logo + Rectángulo CARGO
              _buildHeader(numeroComprobante, false),

              pw.SizedBox(height: 3),

              // Marca de reimpresión si aplica
              if (isReprint)
                pw.Center(
                  child: pw.Container(
                    color: PdfColors.grey200,
                    padding: pw.EdgeInsets.all(3),
                    margin: pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      'COPIA CLIENTE (REIMPRESIÓN)',
                      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                    ),
                  ),
                )
              else
                pw.Center(
                  child: pw.Text(
                    'COPIA CLIENTE',
                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                  ),
                ),

              pw.SizedBox(height: 6),

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

              pw.SizedBox(height: 4.5),

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
        margin: pw.EdgeInsets.symmetric(vertical: 19, horizontal: 4.5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Rectángulo para cinta adhesiva en la parte superior
              _buildTapeRectangle(),

              pw.SizedBox(height: 6),

              // Encabezado: Logo + Rectángulo CARGO
              _buildHeader(numeroComprobante, false),

              pw.SizedBox(height: 3),

              // Marca de reimpresión si aplica
              if (isReprint)
                pw.Center(
                  child: pw.Container(
                    color: PdfColors.grey200,
                    padding: pw.EdgeInsets.all(3),
                    margin: pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      'COPIA CARGA (REIMPRESIÓN)',
                      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                    ),
                  ),
                )
              else
                pw.Center(
                  child: pw.Text(
                    'COPIA CARGA',
                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                  ),
                ),

              pw.SizedBox(height: 6),

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

              pw.SizedBox(height: 9),

              // Agregar imagen de fin ANTES de la línea de corte
              pw.Center(child: pw.Image(_optimizer.getEndImage(), width: ticketFormat.width * 0.8)),

              pw.SizedBox(height: 6),

              // Rectángulo para cinta adhesiva ANTES de la línea de corte
              _buildTapeRectangle(),

              pw.SizedBox(height: 6),

              // Línea de separación con tijeras
              _buildScissorsLine(),

              pw.SizedBox(height: 9),

              // Control Interno
              pw.Center(
                child: pw.Text(
                  'CONTROL INTERNO',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                ),
              ),

              pw.SizedBox(height: 3),

              _buildControlInternoBox(numeroComprobante, articulo, precio, fecha),

              pw.SizedBox(height: 6),

              // Nuevo box para información de entrega
              _buildDeliveryInfoBox(),

              pw.SizedBox(height: 52),

              pw.Container(width: double.infinity, height: 1.5, color: PdfColors.black),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  // Widget para el encabezado del ticket (Logo + Rectángulo bordes negros CARGO)
  static pw.Widget _buildHeader(String ticketId, bool showCargoLabel) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Logo izquierda
        pw.Container(
          width: 49,
          child: pw.Image(_optimizer.getLogoImage()),
        ),

        pw.SizedBox(width: 4.5),

        // Rectángulo con bordes negros, fondo blanco con CARGO y N° comprobante
        pw.Expanded(
          child: pw.Container(
            padding: pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(width: 1.5, color: PdfColors.black),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'CARGO',
                  style: pw.TextStyle(
                    fontSize: 6.75,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'N° $ticketId',
                  style: pw.TextStyle(
                    fontSize: 6,
                    color: PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
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
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
          padding: pw.EdgeInsets.all(3.75),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Destino:', style: pw.TextStyle(fontSize: 6.75)),
              pw.SizedBox(width: 3),
              pw.Text(
                destino,
                style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 3.75),

        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
          padding: pw.EdgeInsets.all(3.75),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Artículo:', style: pw.TextStyle(fontSize: 6.75)),
              pw.Text(
                articulo,
                style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 3.75),

        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
          padding: pw.EdgeInsets.all(3.75),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Precio:', style: pw.TextStyle(fontSize: 6.75)),
              pw.SizedBox(width: 3),
              pw.Text(
                '\${_priceFormatter.format(precio)}',
                style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 3.75),

        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
          padding: pw.EdgeInsets.all(3.75),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Destinatario:', style: pw.TextStyle(fontSize: 6.75)),
              pw.Text(
                destinatario,
                style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),

        if (telefonoDest.isNotEmpty) pw.SizedBox(height: 3.75),

        if (telefonoDest.isNotEmpty)
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
            padding: pw.EdgeInsets.all(3.75),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Teléfono Dest.:', style: pw.TextStyle(fontSize: 6.75)),
                pw.SizedBox(width: 3),
                pw.Text(
                  telefonoDest,
                  style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),

        pw.SizedBox(height: 3.75),

        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
          padding: pw.EdgeInsets.all(3.75),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Remitente:', style: pw.TextStyle(fontSize: 6.75)),
              pw.Text(
                remitente,
                style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),

        if (telefonoRemit.isNotEmpty) pw.SizedBox(height: 3.75),

        if (telefonoRemit.isNotEmpty)
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
            padding: pw.EdgeInsets.all(3.75),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Teléfono Remit.:', style: pw.TextStyle(fontSize: 6.75)),
                pw.SizedBox(width: 3),
                pw.Text(
                  telefonoRemit,
                  style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),

        pw.SizedBox(height: 3.75),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('Fecha: $fecha', style: pw.TextStyle(fontSize: 6)),
            pw.SizedBox(width: 6),
            pw.Text('Hora: $hora', style: pw.TextStyle(fontSize: 6)),
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
          padding: pw.EdgeInsets.only(right: 3),
          child: pw.Image(_optimizer.getTijeraImage(), width: 9),
        ),
        pw.Expanded(
          child: pw.Container(
            height: 0.4,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(
                  width: 0.4,
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
      padding: pw.EdgeInsets.all(4.5),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 9),
          pw.Container(
            width: double.infinity,
            child: pw.Text('__________________________', style: pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
          ),
          pw.Text('Nombre', style: pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 9),
          pw.Container(
            width: double.infinity,
            child: pw.Text('__________________________', style: pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
          ),
          pw.Text('R.U.T.', style: pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            child: pw.Text('___________________________', style: pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
          ),
          pw.Text('Firma', style: pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Comprobante N° $ticketId',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Text('Artículo: $articulo', style: pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 3),
          pw.Text('Valor: \$${_priceFormatter.format(precio)}', style: pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Fecha: $fechaDespacho', style: pw.TextStyle(fontSize: 7.5)),
              pw.SizedBox(width: 6),
              pw.Text('Hora: ${DateFormat('HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 7.5)),
            ],
          ),
        ],
      ),
    );
  }
}