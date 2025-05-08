import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'comprobante.dart';
import 'caja_database.dart';

class BusTicketGenerator {
  // Dimensiones ajustadas para coincidir con el formato de impresora térmica
  static final PdfPageFormat ticketFormat = PdfPageFormat(
    58 * PdfPageFormat.mm,  // Ancho estándar para impresoras térmicas
    double.infinity,        // Altura flexible basada en el contenido
  );

  // Método para generar y guardar los tickets
  static Future<void> generateAndPrintTicket({
    required String destino,
    required String horario,
    required String asiento,
    required String valor,
    String? origen,  // Parámetro opcional para destinos intermedios
  }) async {
    try {
      // Verificar si se trata de un destino intermedio
      bool esIntermedio = origen != null;
      String destinoFormateado = destino;

      // Obtener número de comprobante (formato 000001)
      final comprobanteManager = ComprobanteManager();
      final String numeroComprobante = await comprobanteManager.getNextBusComprobante();

      // Generar el PDF
      final pdfBytes = await _generatePdf(
        destino: destinoFormateado,
        origen: origen,
        horario: horario,
        asiento: asiento,
        valor: valor,
        numeroComprobante: numeroComprobante,
        esIntermedio: esIntermedio,
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

  // Méodo para generar el PDF del ticket
  static Future<Uint8List> _generatePdf({
    required String destino,
    String? origen,
    required String horario,
    required String asiento,
    required String valor,
    required String numeroComprobante,
    required bool esIntermedio,
  }) async {
    final doc = pw.Document();

    // Cargar recursos
    final pw.ImageProvider? logoImage = await _loadImageAsset('assets/logobkwt.png');
    final pw.ImageProvider? scissorsImage = await _loadImageAsset('assets/tijera.png');

    // Obtener fecha y hora actuales en formato requerido
    final now = DateTime.now();

    // Formato de fecha: DD | MMM | YY
    final String dia = now.day.toString().padLeft(2, '0');
    final List<String> meses = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
    final String mes = meses[now.month - 1];
    final String anio = (now.year % 100).toString().padLeft(2, '0'); // Solo los últimos 2 dígitos
    final String fechaFormato = "$dia | $mes | $anio";

    // Hora de emisión en formato HH:MM
    final String horaEmision = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Color del texto del asiento (blanco si es 0)
    final asientoColor = asiento == '0' ? PdfColors.white : PdfColors.black;

    doc.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        margin: pw.EdgeInsets.only(top: 0, left: 0, right: 0, bottom: 5),
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
                esIntermedio,
                asientoColor,
              ),

              // Línea de corte con tijera a la izquierda
              pw.Stack(
                alignment: pw.Alignment.centerLeft,
                children: [
                  // Línea punteada gruesa
                  pw.Container(
                    margin: pw.EdgeInsets.symmetric(vertical: 10),
                    child: pw.Row(
                      children: List.generate(
                        (ticketFormat.width / 5).round(),
                            (index) => pw.Container(
                          width: 3,
                          height: 1.5, // Línea más gruesa
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
                padding: pw.EdgeInsets.symmetric(vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey600,
                ),
                child: pw.Text(
                  'CONTROL INTERNO',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize:
                    10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              _buildInspectorTicket(
                destino,
                origen,
                horario,
                asiento,
                valor,
                numeroComprobante,
                fechaFormato,
                horaEmision,
                esIntermedio,
                asientoColor,
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
      bool esIntermedio,
      PdfColor asientoColor,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Cabecera con logo a la izquierda y número de comprobante a la derecha
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Lado izquierdo - Logo más grande
            pw.Container(
              width: ticketFormat.width * 0.5,
              child: logoImage != null
                  ? pw.Image(logoImage)
                  : pw.Text('Buses Suray', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),

            // Lado derecho - Cuadro con borde para el número de comprobante
            pw.Container(
              width: 87,
              height: 50,
              padding: pw.EdgeInsets.all(7),
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
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'DE PAGO',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'N° $numeroComprobante',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 8),

        // Título de BOLETO DE BUS
        pw.Text(
          'BOLETO DE BUS',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 8),
        pw.Divider(),

        // Origen (solo para destinos intermedios) - CENTRADO
        if (esIntermedio && origen != null)
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            padding: pw.EdgeInsets.all(8),
            width: double.infinity,
            margin: pw.EdgeInsets.only(bottom: 5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'ORIGEN:',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.normal),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  origen,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),

        // Destino (centrado)
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          padding: pw.EdgeInsets.all(8),
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'DESTINO:',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.normal),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                destino,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 5),

        // Fila con horario y fecha (dos contenedores uno al lado del otro)
        pw.Row(
          children: [
            // Horario (izquierda)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                padding: pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Salida:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.normal),
                    ),
                    pw.Text(
                      horario,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 3), // Espacio entre los dos contenedores

            // Fecha (derecha)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                padding: pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FECHA:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.normal),
                    ),
                    pw.Text(
                      fechaFormato,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

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
          'PRESENTARSE 10 MINUTOS ANTES DE LA SALIDA DEL BUS',
          style: pw.TextStyle(
            fontSize: 9,
            fontStyle: pw.FontStyle.italic,
          ),
          textAlign: pw.TextAlign.center,
        ),

        pw.SizedBox(height: 5), // Espacio después del texto

        // Fila con asiento y valor (dos contenedores uno al lado del otro)
        pw.Row(
          children: [
            // Asiento (izquierda)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                padding: pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ASIENTO:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.normal),
                    ),
                    pw.Text(
                      asiento,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: asientoColor),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 3), // Espacio entre los dos contenedores

            // Valor (derecha)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                padding: pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VALOR:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.normal),
                    ),
                    pw.Text(
                      '\$${_formatPrice(double.parse(valor))}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        // Hora de emisión
        pw.Text(
          'Emisión: $horaEmision - $fechaFormato',
          style: pw.TextStyle(fontSize: 10),
          textAlign: pw.TextAlign.center,
        ),

        pw.SizedBox(height: 10),
      ],
    );
  }

  // Método para construir el ticket del inspector (compacto)
  static pw.Widget _buildInspectorTicket(
      String destino,
      String? origen,
      String horario,
      String asiento,
      String valor,
      String numeroComprobante,
      String fechaFormato,
      String horaEmision,
      bool esIntermedio,
      PdfColor asientoColor,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Número de comprobante centrado
        pw.Container(
          width: 100,
          padding: pw.EdgeInsets.all(7),
          margin: pw.EdgeInsets.only(top: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.5),
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'N° $numeroComprobante',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 8),

        // Información resumida y compacta
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Origen (solo si es intermedio)
              if (esIntermedio && origen != null)
                _buildCompactInfoRow('Origen', origen),

              // Resto de información
              _buildCompactInfoRow('Destino', destino),
              _buildCompactInfoRow('Salida',horario),
              _buildCompactInfoRow('Fecha', fechaFormato),
              _buildCompactInfoRow('Asiento', asiento, textColor: asientoColor),
              pw.Divider(height: 5),
              // Valor después del divisor
              _buildCompactInfoRow('Valor', '\$${_formatPrice(double.parse(valor))}'),
              // Emitido después del valor
              _buildCompactInfoRow('Hora emisión', horaEmision),
              _buildCompactInfoRow('Fecha emisión', fechaFormato),
            ],
          ),
        ),

        // Área para insertar en planilla
        pw.Container(
          width: double.infinity,
          height: 140, // Altura aproximada para dos cuadrantes de asiento
          margin: pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.black, width: 0.5),
              left: pw.BorderSide(color: PdfColors.black, width: 0.05),
              right: pw.BorderSide(color: PdfColors.black, width: 0.05),
            ),
          ),
        ),
        // Línea negra inferior
        pw.Container(
          width: double.infinity,
          height: 2,
          color: PdfColors.black,
        ),

        pw.SizedBox(height: 10),
      ],
    );
  }

  // Método para crear filas de información compactas para el inspector
  static pw.Widget _buildCompactInfoRow(String label, String value, {PdfColor? textColor}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '$label:',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, color: textColor),
        ),
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