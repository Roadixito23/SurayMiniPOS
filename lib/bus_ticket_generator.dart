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
  // Dimensiones ajustadas para coincidir con el formato de cargo
  static final PdfPageFormat ticketFormat = PdfPageFormat(
    58 * PdfPageFormat.mm,  // Ancho estándar para impresoras térmicas
    double.infinity,        // Altura flexible basada en el contenido
  );

  static Future<void> generateAndPrintTicket({
    required String destino,
    required String horario,
    required String asiento,
    required String valor,
  }) async {
    // Obtener número de comprobante (formato 000001)
    final comprobanteManager = ComprobanteManager();
    final String numeroComprobante = await comprobanteManager.getNextBusComprobante();

    final pdf = await _generatePdf(
      destino: destino,
      horario: horario,
      asiento: asiento,
      valor: valor,
      numeroComprobante: numeroComprobante,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf,
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
  }

  static Future<Uint8List> _generatePdf({
    required String destino,
    required String horario,
    required String asiento,
    required String valor,
    required String numeroComprobante,
  }) async {
    final doc = pw.Document();

    // Cargar el logo y la tijera
    final pw.ImageProvider? logoImage = await _loadImageAsset('assets/logobkwt.png');
    final pw.ImageProvider? scissorsImage = await _loadImageAsset('assets/tijera.png');

    // Obtener fecha actual y formatearla
    final now = DateTime.now();
    final String dia = now.day.toString().padLeft(2, '0');
    final List<String> meses = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
    final String mes = meses[now.month - 1];
    final String anio = (now.year % 100).toString().padLeft(2, '0'); // Solo los últimos 2 dígitos
    final String fechaFormato = "$dia | $mes | $anio";

    final String horaEmision = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    doc.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        margin: pw.EdgeInsets.only(top: 0, left: 0, right: 0, bottom: 5), // Margen inferior para evitar información en impresora
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // PRIMERA PARTE: PASAJERO
              _buildPassengerTicket(
                  logoImage,
                  destino,
                  horario,
                  asiento,
                  valor,
                  numeroComprobante,
                  fechaFormato,
                  horaEmision
              ),

              // Línea de corte punteada con imagen de tijera en el lado izquierdo
              pw.Stack(
                alignment: pw.Alignment.centerLeft, // Alineado a la izquierda
                children: [
                  // Línea punteada
                  pw.Container(
                    margin: pw.EdgeInsets.symmetric(vertical: 10),
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

                  // Imagen de tijera en el lado izquierdo
                  scissorsImage != null
                      ? pw.Positioned(
                    left: 5, // Posición desde la izquierda
                    child: pw.Container(
                      width: 15, // Ancho controlado para la imagen
                      height: 15, // Alto controlado para la imagen
                      child: pw.Image(scissorsImage),
                    ),
                  )
                      : pw.SizedBox(),
                ],
              ),

              // Texto indicador de corte con fondo gris en lugar de negro
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.symmetric(vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey600, // Gris para optimizar el uso de tinta
                ),
                child: pw.Text(
                  'CORTE INSPECTOR',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              // SEGUNDA PARTE: INSPECTOR (compacta)
              _buildInspectorTicket(
                  destino,
                  horario,
                  asiento,
                  valor,
                  numeroComprobante,
                  fechaFormato,
                  horaEmision
              ),

              // Siempre añadir espacio adicional al final para prevenir cortes en la impresora
              pw.SizedBox(height: 15),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // Método para construir el ticket del pasajero (optimizado)
  static pw.Widget _buildPassengerTicket(
      pw.ImageProvider? logoImage,
      String destino,
      String horario,
      String asiento,
      String valor,
      String numeroComprobante,
      String fechaFormato,
      String horaEmision
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Cabecera con logo a la izquierda y número de comprobante a la derecha
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Lado izquierdo - Logo
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
                      fontSize: 10,
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
                      'HORA:',
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
            'Válidos en hora y fechas señaladas',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),

        // Texto de recomendación
        pw.Text(
          'PRESENTARSE 10 MINUNTOS ANTES DE LA SALIDA DEL BUS',
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
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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
      String horario,
      String asiento,
      String valor,
      String numeroComprobante,
      String fechaFormato,
      String horaEmision
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Número de comprobante centrado (sin título)
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

        // Información resumida y compacta con orden reorganizado
        pw.Container(
          padding: pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildCompactInfoRow('Destino', destino),
              _buildCompactInfoRow('Hora', horario),
              _buildCompactInfoRow('Fecha', fechaFormato),
              _buildCompactInfoRow('Asiento', asiento),
              pw.Divider(height: 5),
              // Valor movido después del divisor
              _buildCompactInfoRow('Valor', '\$${_formatPrice(double.parse(valor))}'),
              // Emitido después del valor
              _buildCompactInfoRow('Emitido', horaEmision),
            ],
          ),
        ),

        pw.SizedBox(height: 10),
      ],
    );
  }

  // Método para crear filas de información compactas para el inspector
  static pw.Widget _buildCompactInfoRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '$label:',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  // Método para cargar imágenes con manejo de errores simplificado
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