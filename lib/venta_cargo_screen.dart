import 'package:flutter/material.dart';

class VentaCargoScreen extends StatefulWidget {
  @override
  _VentaCargoScreenState createState() => _VentaCargoScreenState();
}

class _VentaCargoScreenState extends State<VentaCargoScreen> {
  // Controladores para los campos de texto
  final TextEditingController remitenteController = TextEditingController();
  final TextEditingController contactoRemitenteController = TextEditingController();
  final TextEditingController destinatarioController = TextEditingController();
  final TextEditingController contactoDestinatarioController = TextEditingController();
  final TextEditingController origenController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController pesoController = TextEditingController();
  final TextEditingController dimensionesController = TextEditingController();

  String tipoCarga = 'Paquete';
  String metodoEnvio = 'Estándar';
  double precio = 0.0;

  List<String> tiposCarga = ['Paquete', 'Documento', 'Frágil', 'Perecedero', 'Pesado'];
  List<String> metodosEnvio = ['Estándar', 'Express', 'Prioritario'];

  @override
  void dispose() {
    remitenteController.dispose();
    contactoRemitenteController.dispose();
    destinatarioController.dispose();
    contactoDestinatarioController.dispose();
    origenController.dispose();
    destinoController.dispose();
    descripcionController.dispose();
    pesoController.dispose();
    dimensionesController.dispose();
    super.dispose();
  }

  // Calcular precio basado en tipo de carga y método de envío
  void calcularPrecio() {
    double precioBase = 25.0;
    double factorTipoCarga = 1.0;
    double factorMetodoEnvio = 1.0;

    // Factor por tipo de carga
    switch (tipoCarga) {
      case 'Documento': factorTipoCarga = 0.8; break;
      case 'Frágil': factorTipoCarga = 1.5; break;
      case 'Perecedero': factorTipoCarga = 1.8; break;
      case 'Pesado': factorTipoCarga = 2.0; break;
      default: factorTipoCarga = 1.0;
    }

    // Factor por método de envío
    switch (metodoEnvio) {
      case 'Express': factorMetodoEnvio = 1.5; break;
      case 'Prioritario': factorMetodoEnvio = 2.0; break;
      default: factorMetodoEnvio = 1.0;
    }

    // Calcular precio total
    double peso = double.tryParse(pesoController.text) ?? 1.0;
    precio = precioBase * factorTipoCarga * factorMetodoEnvio * (peso > 1 ? peso : 1);

    setState(() {}); // Actualizar UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generar Venta Cargo'),
        centerTitle: true,
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de datos del remitente
            buildSectionTitle('Datos del Remitente'),
            SizedBox(height: 10.0),
            buildTextField(remitenteController, 'Nombre Completo', Icons.person),
            SizedBox(height: 10.0),
            buildTextField(contactoRemitenteController, 'Teléfono/Email', Icons.contact_phone),

            SizedBox(height: 20.0),

            // Sección de datos del destinatario
            buildSectionTitle('Datos del Destinatario'),
            SizedBox(height: 10.0),
            buildTextField(destinatarioController, 'Nombre Completo', Icons.person_outline),
            SizedBox(height: 10.0),
            buildTextField(contactoDestinatarioController, 'Teléfono/Email', Icons.contact_phone),

            SizedBox(height: 20.0),

            // Sección de información de ruta
            buildSectionTitle('Información de Ruta'),
            SizedBox(height: 10.0),
            Row(
              children: [
                Expanded(child: buildTextField(origenController, 'Origen', Icons.location_on)),
                SizedBox(width: 10.0),
                Expanded(child: buildTextField(destinoController, 'Destino', Icons.location_on_outlined)),
              ],
            ),

            SizedBox(height: 20.0),

            // Sección de detalles del cargo
            buildSectionTitle('Detalles del Cargo'),
            SizedBox(height: 10.0),

            // Tipo de carga (Dropdown)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: tipoCarga,
                  hint: Text('Tipo de Carga'),
                  items: tiposCarga.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      tipoCarga = newValue!;
                      calcularPrecio();
                    });
                  },
                ),
              ),
            ),

            SizedBox(height: 15.0),

            // Método de envío (Dropdown)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: metodoEnvio,
                  hint: Text('Método de Envío'),
                  items: metodosEnvio.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      metodoEnvio = newValue!;
                      calcularPrecio();
                    });
                  },
                ),
              ),
            ),

            SizedBox(height: 15.0),

            // Descripción, peso y dimensiones
            buildTextField(descripcionController, 'Descripción del Cargo', Icons.description),
            SizedBox(height: 15.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pesoController,
                    decoration: InputDecoration(
                      labelText: 'Peso (kg)',
                      prefixIcon: Icon(Icons.line_weight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      calcularPrecio();
                    },
                  ),
                ),
                SizedBox(width: 10.0),
                Expanded(
                  child: buildTextField(dimensionesController, 'Dimensiones', Icons.straighten),
                ),
              ],
            ),

            SizedBox(height: 25.0),

            // Sección de resumen de venta
            buildSectionTitle('Resumen de Venta'),
            SizedBox(height: 10.0),
            Container(
              padding: EdgeInsets.all(15.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  buildSummaryRow('Ruta:', '${origenController.text} - ${destinoController.text}'),
                  buildSummaryRow('Tipo de Carga:', tipoCarga),
                  buildSummaryRow('Método de Envío:', metodoEnvio),
                  buildSummaryRow('Peso:', '${pesoController.text} kg'),
                  Divider(thickness: 1),
                  buildSummaryRow('Precio Total:', 'S/. ${precio.toStringAsFixed(2)}', isBold: true),
                ],
              ),
            ),

            SizedBox(height: 30.0),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    calcularPrecio();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.blue,
                  ),
                  child: Text('Calcular Precio'),
                ),
                SizedBox(width: 20.0),
                ElevatedButton(
                  onPressed: () {
                    // Acción para generar venta
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Venta de cargo generada con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Navegar de regreso después de un retraso
                    Future.delayed(Duration(seconds: 2), () {
                      Navigator.pop(context);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.green,
                  ),
                  child: Text('Confirmar Venta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget para títulos de sección
  Widget buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.orange.shade800,
      ),
    );
  }

  // Widget para campos de texto
  Widget buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
      ),
    );
  }

  // Widget para filas de resumen
  Widget buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value.isEmpty ? 'No especificado' : value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.orange.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}