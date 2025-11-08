# Implementación de Funcionalidades en Desarrollo

Este documento describe las funcionalidades implementadas para SurayMiniPOS.

## Funcionalidades Implementadas ✅

### 1. Sistema de Comprobantes Individualizados por Tipo de Boleto

**Archivo**: `lib/models/comprobante.dart`

- ✅ Contadores separados para cada tipo de boleto:
  - PUBLICO GENERAL
  - ESCOLAR
  - ADULTO MAYOR
  - INTERMEDIO 15KM
  - INTERMEDIO 50KM
  - CARGO

- ✅ Métodos actualizados:
  - `getNextBusComprobante(tipoBoleto)` - Requiere tipo de boleto
  - `getNextCargoComprobante()` - Para servicios de carga
  - `getLastSoldComprobante(tipoBoleto)` - Obtiene el último vendido
  - `getCurrentCounter(tipoBoleto)` - Consulta contador actual
  - `getAllCounters()` - Obtiene todos los contadores

### 2. Sistema de Métodos de Pago

**Archivo**: `lib/database/caja_database.dart`

- ✅ Soporte para 3 métodos de pago:
  1. **Efectivo** - 100% en efectivo
  2. **Tarjeta** - 100% con tarjeta
  3. **Personalizar** - División entre efectivo y tarjeta

- ✅ Registros de venta actualizados:
  - `registrarVentaBus()` - Ahora incluye metodoPago, montoEfectivo, montoTarjeta, tipoBoleto
  - `registrarVentaCargo()` - Ahora incluye metodoPago, montoEfectivo, montoTarjeta

- ✅ Estructura de ventas en JSON:
```json
{
  "tipo": "bus",
  "destino": "Aysen",
  "tipoBoleto": "PUBLICO GENERAL",
  "valor": 3600.0,
  "metodoPago": "Personalizar",
  "montoEfectivo": 2000.0,
  "montoTarjeta": 1600.0,
  ...
}
```

### 3. Sistema de Gastos

**Archivo**: `lib/database/caja_database.dart`

- ✅ Dos tipos de gastos:
  1. **Combustible**:
     - N° de Máquina (máximo 6 caracteres alfanuméricos)
     - Chofer
     - Monto en efectivo

  2. **Otros**:
     - Descripción
     - Monto en efectivo

- ✅ Métodos implementados:
  - `registrarGasto()` - Registra un gasto
  - `getGastosDiarios()` - Obtiene gastos del día
  - Respaldo automático en `gastos_diarios.json`

### 4. Control de Caja por Tipo de Boleto

**Archivo**: `lib/database/caja_database.dart` - Método `realizarCierreCaja()`

- ✅ Genera control de caja automáticamente al cerrar:
  - Tipo de boleto
  - Primer comprobante vendido
  - Último comprobante vendido
  - Cantidad de boletos vendidos
  - Subtotal por tipo

- ✅ Cálculos de totales:
  - `totalEfectivo` - Total cobrado en efectivo
  - `totalTarjeta` - Total cobrado con tarjeta
  - `totalGastos` - Total de gastos del día
  - `efectivoFinal` - Efectivo después de descontar gastos
  - `controlCaja` - Array con desglose por tipo de boleto

### 5. Widgets Reutilizables

**Archivo**: `lib/widgets/shared_widgets.dart`

- ✅ **PaymentMethodDialog**: Selección de método de pago
  - Radio buttons para Efectivo/Tarjeta/Personalizar
  - Validación de sumas en modo Personalizar
  - Advertencia si excede efectivo disponible
  - Retorna: `{metodo, montoEfectivo, montoTarjeta}`

- ✅ **ExpenseDialog**: Registro de gastos
  - Radio buttons para Combustible/Otros
  - Campos dinámicos según tipo
  - Validación de N° de máquina (máx 6 caracteres)
  - Advertencia si excede efectivo disponible
  - Retorna: `{tipoGasto, monto, numeroMaquina, chofer, descripcion}`

### 6. Actualización de Generadores de PDF

**Archivos**:
- `lib/services/bus_ticket_generator.dart`
- `lib/services/cargo_ticket_generator.dart`

- ✅ Parámetros agregados:
  - `metodoPago` (default: 'Efectivo')
  - `montoEfectivo` (opcional)
  - `montoTarjeta` (opcional)

- ✅ Uso de comprobantes individualizados
- ✅ Registro automático con método de pago

## Funcionalidades Pendientes 🔄

### 1. Actualizar Pantallas de Venta

#### VentaBusScreen (`lib/screens/venta_bus_screen.dart`)

**Cambios necesarios**:

1. Agregar import:
```dart
import '../widgets/shared_widgets.dart';
import 'package:provider/provider.dart';
import '../models/auth_provider.dart';
```

2. En el método `_confirmarVenta()`, antes de llamar a `BusTicketGenerator.generateAndPrintTicket()`:
```dart
// Mostrar diálogo de método de pago
final paymentResult = await showDialog<Map<String, dynamic>>(
  context: context,
  builder: (context) => PaymentMethodDialog(
    totalAmount: double.parse(valorBoleto),
  ),
);

if (paymentResult == null) return; // Usuario canceló

// Pasar los datos de pago al generador
await BusTicketGenerator.generateAndPrintTicket(
  // ... parámetros existentes ...
  metodoPago: paymentResult['metodo'],
  montoEfectivo: paymentResult['montoEfectivo'],
  montoTarjeta: paymentResult['montoTarjeta'],
);
```

3. **Ocultar teclado para rol Secretaria**:
```dart
// En el widget build(), envolver el NumericKeyboard con:
final authProvider = Provider.of<AuthProvider>(context);

// Luego, donde se muestra el teclado:
if (!authProvider.isSecretaria)
  NumericKeyboard(...),
```

#### VentaCargoScreen (`lib/screens/venta_cargo_screen.dart`)

Similar a VentaBusScreen, agregar PaymentMethodDialog antes de generar el ticket.

### 2. Actualizar CierreCajaScreen

**Archivo**: `lib/screens/cierre_caja_screen.dart`

**Cambios necesarios**:

1. Agregar botón "Agregar Gasto" en la pantalla:
```dart
ElevatedButton.icon(
  icon: Icon(Icons.receipt_long),
  label: Text('Agregar Gasto'),
  onPressed: _agregarGasto,
),
```

2. Implementar método `_agregarGasto()`:
```dart
Future<void> _agregarGasto() async {
  // Calcular efectivo disponible
  final ventas = await CajaDatabase().getVentasDiarias();
  double efectivoDisponible = ventas.fold(0.0, (sum, v) =>
    sum + (v['montoEfectivo'] ?? 0.0)
  );

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => ExpenseDialog(
      efectivoDisponible: efectivoDisponible,
    ),
  );

  if (result != null) {
    await CajaDatabase().registrarGasto(
      tipoGasto: result['tipoGasto'],
      monto: result['monto'],
      numeroMaquina: result['numeroMaquina'],
      chofer: result['chofer'],
      descripcion: result['descripcion'],
    );

    setState(() {}); // Refrescar la pantalla
  }
}
```

3. Mostrar resumen de ventas por método de pago:
```dart
Card(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text('Resumen de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        _buildRow('Total en Efectivo:', '\$${totalEfectivo.toStringAsFixed(0)}'),
        _buildRow('Total en Tarjeta:', '\$${totalTarjeta.toStringAsFixed(0)}'),
        Divider(),
        _buildRow('Total Gastos:', '\$${totalGastos.toStringAsFixed(0)}', color: Colors.red),
        Divider(),
        _buildRow('Efectivo Final:', '\$${efectivoFinal.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    ),
  ),
)
```

4. Mostrar tabla de Control de Caja:
```dart
if (controlCaja.isNotEmpty)
  Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Control de Caja', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Table(
            border: TableBorder.all(),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[200]),
                children: [
                  _buildTableHeader('Tipo'),
                  _buildTableHeader('Inicio'),
                  _buildTableHeader('Fin'),
                  _buildTableHeader('Cant.'),
                  _buildTableHeader('Subtotal'),
                ],
              ),
              ...controlCaja.map((item) => TableRow(
                children: [
                  _buildTableCell(item['tipo']),
                  _buildTableCell(item['primerComprobante']),
                  _buildTableCell(item['ultimoComprobante']),
                  _buildTableCell(item['cantidad'].toString()),
                  _buildTableCell('\$${item['subtotal'].toStringAsFixed(0)}'),
                ],
              )),
            ],
          ),
        ],
      ),
    ),
  )
```

### 3. Actualizar Reporte PDF de Cierre

**Archivo**: `lib/services/cierre_caja_report_generator.dart`

**Cambios necesarios**:

Agregar secciones en el PDF para:
- Totales por método de pago
- Listado de gastos
- Tabla de control de caja
- Efectivo final después de gastos

### 4. Actualizar TarifasScreen

**Archivo**: `lib/screens/tarifas_screen.dart`

**Cambios necesarios**:

En la visualización de cada tarifa, mostrar el último N° de comprobante:

```dart
import '../models/comprobante.dart';

// En el build de cada tarifa:
FutureBuilder<String>(
  future: ComprobanteManager().getLastSoldComprobante(tarifa.categoria),
  builder: (context, snapshot) {
    return Text(
      'Último N°: ${snapshot.data ?? 'Cargando...'}',
      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
    );
  },
)
```

## Estructura de Datos

### Venta con Método de Pago
```json
{
  "tipo": "bus",
  "destino": "Aysen",
  "horario": "08:00",
  "asiento": "A1",
  "valor": 3600.0,
  "comprobante": "AYS-01-000001",
  "tipoBoleto": "PUBLICO GENERAL",
  "metodoPago": "Personalizar",
  "montoEfectivo": 2000.0,
  "montoTarjeta": 1600.0,
  "timestamp": 1234567890,
  "fecha": "2025-11-08",
  "hora": "14:30:00"
}
```

### Gasto
```json
{
  "tipoGasto": "Combustible",
  "monto": 50000.0,
  "numeroMaquina": "AB123",
  "chofer": "Juan Pérez",
  "descripcion": null,
  "timestamp": 1234567890,
  "fecha": "2025-11-08",
  "hora": "15:00:00"
}
```

### Cierre de Caja (Estructura Actualizada)
```json
{
  "timestamp": 1234567890,
  "fecha": "2025-11-08",
  "hora": "18:00:00",
  "usuario": "admin",
  "observaciones": "",
  "totalBus": 18000.0,
  "totalCargo": 15000.0,
  "total": 33000.0,
  "cantidadBus": 5,
  "cantidadCargo": 3,
  "cantidad": 8,
  "totalEfectivo": 20000.0,
  "totalTarjeta": 13000.0,
  "totalGastos": 50000.0,
  "efectivoFinal": -30000.0,
  "controlCaja": [
    {
      "tipo": "PUBLICO GENERAL",
      "primerComprobante": "AYS-01-000001",
      "ultimoComprobante": "AYS-01-000003",
      "cantidad": 3,
      "subtotal": 10800.0
    },
    {
      "tipo": "ESCOLAR",
      "primerComprobante": "AYS-01-000001",
      "ultimoComprobante": "AYS-01-000002",
      "cantidad": 2,
      "subtotal": 5000.0
    }
  ],
  "gastos": [...],
  "ventas": [...]
}
```

## Notas de Implementación

1. **Compatibilidad hacia atrás**: Los registros antiguos sin `metodoPago` se tratarán como "Efectivo" por defecto.

2. **Validaciones**:
   - En modo Personalizar, la suma de efectivo + tarjeta debe ser exacta al total
   - El N° de máquina debe ser máximo 6 caracteres alfanuméricos
   - Los gastos pueden exceder el efectivo disponible (con advertencia)

3. **Control de Caja**:
   - Solo se muestran los tipos de boleto que tuvieron ventas
   - Los comprobantes se ordenan automáticamente
   - El control se genera automáticamente en cada cierre

4. **Rol Secretaria**:
   - No puede ver el teclado numérico personalizado
   - Debe usar los valores predeterminados de tarifas
   - Mantiene acceso a todas las demás funcionalidades

## Archivos Modificados

- ✅ `lib/models/comprobante.dart`
- ✅ `lib/database/caja_database.dart`
- ✅ `lib/services/bus_ticket_generator.dart`
- ✅ `lib/services/cargo_ticket_generator.dart`
- ✅ `lib/widgets/shared_widgets.dart`

## Archivos Pendientes de Modificar

- 🔄 `lib/screens/venta_bus_screen.dart`
- 🔄 `lib/screens/venta_cargo_screen.dart`
- 🔄 `lib/screens/cierre_caja_screen.dart`
- 🔄 `lib/screens/tarifas_screen.dart`
- 🔄 `lib/services/cierre_caja_report_generator.dart`

## Testing

Para probar las funcionalidades implementadas:

1. **Comprobantes Individualizados**:
   - Vender boletos de diferentes tipos
   - Verificar que cada tipo tiene su propio contador

2. **Métodos de Pago**:
   - Probar venta en Efectivo
   - Probar venta con Tarjeta
   - Probar venta Personalizada (ejemplo: $2000 efectivo + $1600 tarjeta para total $3600)

3. **Gastos**:
   - Registrar gasto de Combustible
   - Registrar gasto de Otros
   - Verificar advertencia cuando excede efectivo disponible

4. **Control de Caja**:
   - Realizar ventas de diferentes tipos de boleto
   - Hacer cierre de caja
   - Verificar que el control muestra correctamente primer y último comprobante de cada tipo
   - Verificar que no muestra tipos sin ventas

5. **Rol Secretaria**:
   - Login como secretaria
   - Verificar que el teclado numérico NO aparece en venta de boletos
