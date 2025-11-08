import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/comprobante.dart';
import '../database/caja_database.dart';

class BusTicketGenerator {
  // Dimensiones ajustadas para impresora térmica de 60mm (25% más pequeño)
  static final PdfPageFormat ticketFormat = PdfPageFormat(
    60 * PdfPageFormat.mm,  // Ancho de 60mm para ahorrar papel térmico
    double.infinity,        // Altura flexible basada en el contenido
  );

  // Método para generar y guardar los tickets
  static Future<void> generateAndPrintTicket({
    required String destino,
    required String horario,
    required String asiento,
    required String valor,
    required String tipoDia,       // "LUNES A SÁBADO" o "DOMINGO / FERIADO"
    required String tituloTarifa,  // "PUBLICO GENERAL", "ESCOLAR", etc.
    String? origen,                // Parámetro opcional para destinos intermedios
    String? kilometros,            // Para intermedios: "15", "50", etc.
    String metodoPago = 'Efectivo', // Método de pago: "Efectivo", "Tarjeta", "Personalizar"
    double? montoEfectivo,         // Para método personalizado
    double? montoTarjeta,          // Para método personalizado
  }) async {
    try {
      // Verificar si se trata de un destino intermedio
      bool esIntermedio = origen != null || kilometros != null;

      // Determinar el tipo de boleto exacto para el comprobante
      String tipoBoleto = tituloTarifa;

      // Obtener número de comprobante (formato AYS-01-000001 o COY-01-000001)
      // Ahora con comprobantes individualizados por tipo de boleto
      final comprobanteManager = ComprobanteManager();
      final String numeroComprobante = await comprobanteManager.getNextBusComprobante(tipoBoleto);

      // Generar el PDF
      final pdfBytes = await _generatePdf(
        destino: destino,
        origen: origen,
        horario: horario,
        asiento: asiento,
        valor: valor,
        numeroComprobante: numeroComprobante,
        tipoDia: tipoDia,
        tituloTarifa: tituloTarifa,
        esIntermedio: esIntermedio,
        kilometros: kilometros,
        metodoPago: metodoPago,
      );

      // Imprimir el PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        format: ticketFormat,
      );

      // Registrar la venta en la base de datos de caja con método de pago
      final cajaDatabase = CajaDatabase();
      await cajaDatabase.registrarVentaBus(
        destino: destino,
        horario: horario,
        asiento: asiento,
        valor: double.parse(valor),
        comprobante: numeroComprobante,
        tipoBoleto: tipoBoleto,
        metodoPago: metodoPago,
        montoEfectivo: montoEfectivo,
        montoTarjeta: montoTarjeta,
      );

    } catch (e) {
      // Manejar errores de generación e impresión
      debugPrint('Error al generar e imprimir ticket: $e');
      throw Exception('Error al generar ticket: $e');
    }
  }

  // Método para generar el PDF del ticket
  static Future<Uint8List> _generatePdf({
    required String destino,
    String? origen,
    required String horario,
    required String asiento,
    required String valor,
    required String numeroComprobante,
    required String tipoDia,
    required String tituloTarifa,
    required bool esIntermedio,
    String? kilometros,
    String metodoPago = 'Efectivo', // Método de pago agregado
  }) async {
    final doc = pw.Document();

    // Cargar recursos
    final pw.ImageProvider? logoImage = await _loadImageAsset('assets/logobkwt.png');
    final pw.ImageProvider? scissorsImage = await _loadImageAsset('assets/tijera.png');

    // Obtener fecha y hora actuales en formato requerido
    final now = DateTime.now();

    // Formato de fecha sin separadores "|"
    final String dia = now.day.toString().padLeft(2, '0');
    final List<String> meses = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
    final String mes = meses[now.month - 1];
    final String anio = (now.year % 100).toString().padLeft(2, '0');
    final String fechaFormato = "$dia $mes $anio";

    // Hora de emisión en formato HH:MM
    final String horaEmision = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Color del texto del asiento (blanco si es 0)
    final asientoColor = asiento == '0' ? PdfColors.white : PdfColors.black;

    doc.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        margin: pw.EdgeInsets.only(top: 15, left: 6, right: 6, bottom: 15),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // PRIMERA PARTE: TICKET DEL PASAJERO
              _buildPassengerTicket(
                logoImage,
                destino,
                origen,
                horario,
                asiento,
                valor,
                numeroComprobante,
                fechaFormato,
                horaEmision,
                tipoDia,
                tituloTarifa,
                esIntermedio,
                kilometros,
                asientoColor,
              ),

              // Línea de corte con tijera a la izquierda
              pw.Stack(
                alignment: pw.Alignment.centerLeft,
                children: [
                  // Línea punteada gruesa
                  pw.Container(
                    margin: pw.EdgeInsets.symmetric(vertical: 11),
                    child: pw.Row(
                      children: List.generate(
                        (ticketFormat.width / 5).round(),
                            (index) => pw.Container(
                          width: 2.25,
                          height: 1.1,
                          color: PdfColors.black,
                          margin: pw.EdgeInsets.only(right: 1.5),
                        ),
                      ),
                    ),
                  ),

                  // Tijera en el lado izquierdo
                  scissorsImage != null
                      ? pw.Positioned(
                    left: 4,
                    child: pw.Container(
                      width: 11,
                      height: 11,
                      child: pw.Image(scissorsImage),
                    ),
                  )
                      : pw.SizedBox(),
                ],
              ),

              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.symmetric(vertical: 4.5),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey600,
                ),
                child: pw.Text(
                  'CONTROL INTERNO',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8.25,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              _buildInspectorTicket(
                destino,
                horario,
                valor,
                fechaFormato,
                numeroComprobante,
              ),

              // Espacio adicional al final
              pw.SizedBox(height: 15),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // Método para construir el ticket del pasajero
  static pw.Widget _buildPassengerTicket(
      pw.ImageProvider? logoImage,
      String destino,
      String? origen,
      String horario,
      String asiento,
      String valor,
      String numeroComprobante,
      String fechaFormato,
      String horaEmision,
      String tipoDia,
      String tituloTarifa,
      bool esIntermedio,
      String? kilometros,
      PdfColor asientoColor,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // CABECERA: LOGO A LA IZQUIERDA Y RECTÁNGULO NEGRO A LA DERECHA
        pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo izquierda
              pw.Container(
                width: 64,
                height: 64,
                child: logoImage != null
                    ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                    : pw.Text('SURAY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ),

              pw.SizedBox(width: 6),

              // Rectángulo negro con tipo de día y N° comprobante
              pw.Expanded(
                child: pw.Container(
                  padding: pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.black,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        tipoDia,
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'N° $numeroComprobante',
                        style: pw.TextStyle(
                          fontSize: 6.75,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 9),

        // TIPO DE TARIFA EN NEGRITAS CENTRADO
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Text(
            tituloTarifa.contains('INTERMEDIO') ? 'INTERMEDIO' : tituloTarifa,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),

        if (kilometros != null) ...[
          pw.Text(
            'KM $kilometros',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
        ],

        pw.SizedBox(height: 6),

        // DESTINO en cuadrado redondeado
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.1),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          padding: pw.EdgeInsets.all(7.5),
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'DESTINO:',
                style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.normal),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                destino,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 6),

        // Fila con SALIDA y FECHA
        pw.Row(
          children: [
            // Salida (izquierda)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                padding: pw.EdgeInsets.all(7.5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'SALIDA:',
                      style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      horario,
                      style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 4),

            // Fecha (derecha)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                padding: pw.EdgeInsets.all(7.5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'FECHA:',
                      style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      fechaFormato,
                      style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 7.5),

        // Texto de validez
        pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          padding: pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            'Válido hora y fecha señaladas',
            style: pw.TextStyle(
              fontSize: 6.75,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),

        // Texto de recomendación
        pw.Text(
          'PRESENTARSE 10 MINS ANTES',
          style: pw.TextStyle(
            fontSize: 6.75,
            fontStyle: pw.FontStyle.italic,
          ),
          textAlign: pw.TextAlign.center,
        ),

        pw.SizedBox(height: 7.5),

        // Fila con asiento y valor
        pw.Row(
          children: [
            // Asiento (izquierda)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                padding: pw.EdgeInsets.all(7.5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'ASIENTO',
                      style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      asiento,
                      style: pw.TextStyle(fontSize: 13.5, fontWeight: pw.FontWeight.bold, color: asientoColor),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 4),

            // Valor (derecha)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                padding: pw.EdgeInsets.all(7.5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'VALOR',
                      style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '\$${_formatPrice(double.parse(valor))}',
                      style: pw.TextStyle(fontSize: 13.5, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 7.5),

        // Hora de emisión (sin N° de comprobante)
        pw.Text(
          'Emisión: $horaEmision - $fechaFormato',
          style: pw.TextStyle(fontSize: 6.75),
          textAlign: pw.TextAlign.center,
        ),

        pw.SizedBox(height: 11),
      ],
    );
  }

  // Método para construir el ticket del inspector (organizado en tablas)
  static pw.Widget _buildInspectorTicket(
      String destino,
      String horario,
      String valor,
      String fechaFormato,
      String numeroComprobante,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 11),

        // Rectángulo negro con N° de comprobante
        pw.Container(
          padding: pw.EdgeInsets.all(7.5),
          decoration: pw.BoxDecoration(
            color: PdfColors.black,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            'N° $numeroComprobante',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),

        pw.SizedBox(height: 9),

        // Tabla con información organizada
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.1),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              // Fila Destino
              pw.Container(
                padding: pw.EdgeInsets.all(7.5),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 0.75),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Destino:',
                      style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      destino,
                      style: pw.TextStyle(fontSize: 8.25),
                    ),
                  ],
                ),
              ),

              // Fila Horario
              pw.Container(
                padding: pw.EdgeInsets.all(7.5),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 0.75),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Horario:',
                      style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      horario,
                      style: pw.TextStyle(fontSize: 8.25),
                    ),
                  ],
                ),
              ),

              // Fila Fecha
              pw.Container(
                padding: pw.EdgeInsets.all(7.5),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 0.75),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Fecha:',
                      style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      fechaFormato,
                      style: pw.TextStyle(fontSize: 8.25),
                    ),
                  ],
                ),
              ),

              // Fila Valor
              pw.Container(
                padding: pw.EdgeInsets.all(7.5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Valor:',
                      style: pw.TextStyle(fontSize: 8.25, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '\$${_formatPrice(double.parse(valor))}',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 11),

        // Área para insertar en planilla
        pw.Container(
          width: double.infinity,
          height: 90,
          margin: pw.EdgeInsets.only(top: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 0.4),
          ),
        ),

        pw.SizedBox(height: 11),
      ],
    );
  }

  // Método para cargar imágenes con manejo de errores
  static Future<pw.ImageProvider?> _loadImageAsset(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error al cargar imagen "$assetPath": $e');
      return null;
    }
  }

  // Método para formatear el precio
  static String _formatPrice(double price) {
    final formatter = NumberFormat('#,##0', 'es_CL');
    return formatter.format(price);
  }
}