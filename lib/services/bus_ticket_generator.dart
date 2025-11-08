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
  // Dimensiones ajustadas para impresora térmica de 80mm
  static final PdfPageFormat ticketFormat = PdfPageFormat(
    80 * PdfPageFormat.mm,  // Ancho de 80mm para impresoras térmicas
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
  }) async {
    try {
      // Verificar si se trata de un destino intermedio
      bool esIntermedio = origen != null || kilometros != null;

      // Obtener número de comprobante (formato AYS-01-000001 o COY-01-000001)
      final comprobanteManager = ComprobanteManager();
      final String numeroComprobante = await comprobanteManager.getNextBusComprobante();

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
      );

      // Imprimir el PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        format: ticketFormat,
      );

      // Registrar la venta en la base de datos de caja
      final cajaDatabase = CajaDatabase();
      await cajaDatabase.registrarVentaBus(
        destino: destino,
        horario: horario,
        asiento: asiento,
        valor: double.parse(valor),
        comprobante: numeroComprobante,
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
        margin: pw.EdgeInsets.only(top: 20, left: 8, right: 8, bottom: 20),
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
                    margin: pw.EdgeInsets.symmetric(vertical: 15),
                    child: pw.Row(
                      children: List.generate(
                        (ticketFormat.width / 5).round(),
                            (index) => pw.Container(
                          width: 3,
                          height: 1.5,
                          color: PdfColors.black,
                          margin: pw.EdgeInsets.only(right: 2),
                        ),
                      ),
                    ),
                  ),

                  // Tijera en el lado izquierdo
                  scissorsImage != null
                      ? pw.Positioned(
                    left: 5,
                    child: pw.Container(
                      width: 15,
                      height: 15,
                      child: pw.Image(scissorsImage),
                    ),
                  )
                      : pw.SizedBox(),
                ],
              ),

              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.symmetric(vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey600,
                ),
                child: pw.Text(
                  'CONTROL INTERNO',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
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
              pw.SizedBox(height: 20),
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
                width: 85,
                height: 85,
                child: logoImage != null
                    ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                    : pw.Text('SURAY', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),

              pw.SizedBox(width: 8),

              // Rectángulo negro con tipo de día y N° comprobante
              pw.Expanded(
                child: pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.black,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        tipoDia,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'N° $numeroComprobante',
                        style: pw.TextStyle(
                          fontSize: 9,
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

        pw.SizedBox(height: 12),

        // TIPO DE TARIFA EN NEGRITAS CENTRADO
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(
            tituloTarifa.contains('INTERMEDIO') ? 'INTERMEDIO' : tituloTarifa,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),

        if (kilometros != null) ...[
          pw.Text(
            'KM $kilometros',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 5),
        ],

        pw.SizedBox(height: 8),

        // DESTINO en cuadrado redondeado
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.5),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          padding: pw.EdgeInsets.all(10),
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'DESTINO:',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                destino,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 8),

        // Fila con SALIDA y FECHA
        pw.Row(
          children: [
            // Salida (izquierda)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'SALIDA:',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      horario,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 5),

            // Fecha (derecha)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'FECHA:',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      fechaFormato,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        // Texto de validez
        pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          padding: pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            'Válido hora y fecha señaladas',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),

        // Texto de recomendación
        pw.Text(
          'PRESENTARSE 10 MINS ANTES',
          style: pw.TextStyle(
            fontSize: 9,
            fontStyle: pw.FontStyle.italic,
          ),
          textAlign: pw.TextAlign.center,
        ),

        pw.SizedBox(height: 10),

        // Fila con asiento y valor
        pw.Row(
          children: [
            // Asiento (izquierda)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'ASIENTO',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      asiento,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: asientoColor),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 5),

            // Valor (derecha)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'VALOR',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '\$${_formatPrice(double.parse(valor))}',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        // Hora de emisión (sin N° de comprobante)
        pw.Text(
          'Emisión: $horaEmision - $fechaFormato',
          style: pw.TextStyle(fontSize: 9),
          textAlign: pw.TextAlign.center,
        ),

        pw.SizedBox(height: 15),
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
        pw.SizedBox(height: 15),

        // Rectángulo negro con N° de comprobante
        pw.Container(
          padding: pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.black,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'N° $numeroComprobante',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),

        pw.SizedBox(height: 12),

        // Tabla con información organizada
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.5),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              // Fila Destino
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 1),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Destino:',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      destino,
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Fila Horario
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 1),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Horario:',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      horario,
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Fila Fecha
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 1),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Fecha:',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      fechaFormato,
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Fila Valor
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Valor:',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '\$${_formatPrice(double.parse(valor))}',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 15),

        // Área para insertar en planilla
        pw.Container(
          width: double.infinity,
          height: 120,
          margin: pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 0.5),
          ),
        ),

        pw.SizedBox(height: 15),
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