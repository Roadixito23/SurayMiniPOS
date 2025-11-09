# Sistema de Gestión de Asientos - Cambios Implementados

## Resumen
Se ha implementado un sistema completo de gestión de asientos de bus con las siguientes características:

### 1. Base de Datos Actualizada (v2)

#### Nuevas Tablas

**Tabla `salidas`**
- Gestiona cada salida de bus por fecha, horario y destino
- Permite reservas hasta 5 semanas en el futuro (35 días)
- Campos: id, fecha, horario, destino, tipo_dia, activo
- Constraint UNIQUE(fecha, horario, destino)

**Tabla `asientos_reservados`**
- Registra qué asientos están ocupados en cada salida
- Relaciona el asiento con el comprobante del boleto
- Campos: id, salida_id, numero_asiento, comprobante, fecha_reserva
- Constraint UNIQUE(salida_id, numero_asiento)
- Foreign key con CASCADE DELETE

#### Nuevos Métodos en AppDatabase
- `crearObtenerSalida()` - Crea o recupera una salida existente
- `getAsientosOcupados(salidaId)` - Obtiene asientos ocupados de una salida
- `reservarAsiento()` - Reserva un asiento para una salida
- `liberarAsiento()` - Libera un asiento reservado
- `getSalidasEnRango()` - Obtiene salidas en un rango de fechas

### 2. Componente Visual de Asientos (BusSeatMap)

**Ubicación**: `lib/widgets/bus_seat_map.dart`

**Características**:
- Muestra 45 asientos del bus en formato visual
- Layout realista del bus:
  - Asientos 1-39: Filas de 2 asientos
  - Impares (1, 3, 5...): Ventana (lado izquierdo)
  - Pares (2, 4, 6...): Pasillo (lado derecho)
  - Última fila especial (40-45): 6 asientos con distribución 40,41,42 | 45 | 43,44

**Código de colores**:
- 🟢 Verde: Asiento disponible
- 🔴 Rojo: Asiento ocupado
- ⚫ Gris: Asiento seleccionado actualmente
- 🔵 Borde azul: Asientos de ventana

**Interacción**:
- Click en asiento disponible: Selecciona el asiento
- Asientos ocupados: No clickeables
- Sincronizado con campo numérico de asiento

### 3. Cambios en Pantalla de Venta (VentaBusScreen)

#### Para SECRETARIAS (rol: Secretaria)
- ❌ **ELIMINADO**: Cuadrante "Valor del Boleto"
- ✅ Solo campos: Horario y Asiento
- ✅ El valor se toma automáticamente de la tarifa seleccionada
- ✅ Al presionar Enter en Asiento, se genera el ticket directamente

#### Para ADMINISTRADORES (rol: Administrador)
- ✅ Campo "Valor del Boleto" visible y editable
- ✅ Pueden modificar el precio manualmente
- ✅ Mantienen acceso al teclado numérico personalizado

#### Nuevas Funcionalidades Generales

**Selector de Fecha**:
- Ubicado en panel izquierdo, antes de "Tipo de Día"
- Permite seleccionar fecha de salida
- Rango: Hoy hasta 5 semanas en el futuro (35 días)
- Formato amigable: "Lunes, 08 noviembre 2025"

**Auto-scroll inteligente**:
- Al presionar Enter en Horario → Auto-scroll + focus en Asiento
- Mejora la experiencia de navegación por teclado

**Mapa de Asientos**:
- Ubicado en panel izquierdo, después de tarifas
- Muestra asientos ocupados en tiempo real
- Click en asiento → Actualiza campo numérico
- Validación: Impide vender asientos ocupados

**Carga Dinámica de Asientos**:
- Al cambiar horario → Carga asientos ocupados
- Al cambiar fecha → Limpia selección y recarga
- Feedback visual inmediato

### 4. Actualización del Generador de Tickets

**Cambio en Firma**:
```dart
// Antes
Future<void> generateAndPrintTicket(...)

// Ahora
//Future<String> generateAndPrintTicket(...)
```

**Retorna**: Número de comprobante generado (ej: "AYS-01-000123")

**Uso**: Permite asociar el asiento reservado con el comprobante del ticket

### 5. Flujo de Venta Actualizado

1. **Selección de Configuración**:
   - Fecha de salida
   - Destino
   - Tipo de día
   - Categoría de tarifa

2. **Selección de Horario**:
   - Usuario ingresa horario
   - Sistema carga/crea salida en BD
   - Carga asientos ocupados de esa salida
   - Actualiza mapa visual

3. **Selección de Asiento**:
   - Opción A: Click en mapa visual
   - Opción B: Ingresar número (01-45)
   - Validación: No permite asientos ocupados
   - Visual feedback en mapa

4. **Confirmación** (solo Admin):
   - Revisar/modificar valor del boleto

5. **Generación de Ticket**:
   - Imprime ticket
   - Reserva asiento en BD
   - Asocia con número de comprobante
   - Recarga mapa de asientos

### 6. Localización en Español

**Dependencia añadida**: `flutter_localizations`

**Configuración**:
- Idioma por defecto: Español (es_ES)
- Formato de fechas en español
- DatePicker en español

### 7. Archivos Modificados

```
lib/
  database/
    app_database.dart            [MODIFICADO] - v2 schema, nuevas tablas y métodos

  widgets/
    bus_seat_map.dart           [NUEVO] - Componente visual de asientos

  screens/
    venta_bus_screen.dart       [MODIFICADO] - Integración completa del sistema

  services/
    bus_ticket_generator.dart   [MODIFICADO] - Retorna comprobante

  main.dart                     [MODIFICADO] - Localización en español

pubspec.yaml                    [MODIFICADO] - Dependencia flutter_localizations

CAMBIOS_GESTION_ASIENTOS.md    [NUEVO] - Este documento
```

### 8. Requisitos de Sistema

**Dependencias**:
- `intl: ^0.18.1` ✅ (ya existente)
- `flutter_localizations` ✅ (agregada)
- `sqflite: ^2.3.0` ✅ (ya existente)
- `provider: ^6.0.5` ✅ (ya existente)

**Migración de Base de Datos**:
- Automática al iniciar la app
- De versión 1 → versión 2
- Conserva datos existentes

### 9. Validaciones Implementadas

- ✅ Asiento debe estar entre 1 y 45
- ✅ No permite vender asientos ocupados
- ✅ Horario en formato HH:MM válido
- ✅ Fecha dentro del rango permitido (hoy + 35 días)
- ✅ Validación de kilómetros para intermedios (1-64)

### 10. Mejoras UX

1. **Visual feedback inmediato**: Colores indican estado del asiento
2. **Navegación por teclado optimizada**: Enter navega campos lógicamente
3. **Auto-scroll inteligente**: Lleva al usuario al siguiente paso
4. **Selector de fecha amigable**: Calendario visual en español
5. **Mapa interactivo**: Click para seleccionar asientos
6. **Prevención de errores**: Asientos ocupados no clickeables

### 11. Próximos Pasos Sugeridos

1. **Historial de Ventas**: Agregar vista de salidas pasadas con asientos vendidos
2. **Reportes**: Dashboard de ocupación por salida
3. **Cancelaciones**: Sistema para liberar asientos de boletos cancelados
4. **Exportación**: PDF/Excel de salidas y ocupación
5. **Estadísticas**: Promedio de ocupación, horarios más vendidos

### 12. Notas Técnicas

**Gestión de Estado**:
- Uso de `setState()` para actualización local
- `Provider` para autenticación y roles

**Rendimiento**:
- Carga asíncrona de asientos ocupados
- Query eficiente con índices únicos
- Lazy loading de mapa de asientos

**Seguridad**:
- Foreign keys con CASCADE DELETE
- Constraints UNIQUE para prevenir duplicados
- Validación de roles en frontend y backend

## Testing Recomendado

1. ✅ Crear salida para hoy
2. ✅ Vender boleto con asiento específico
3. ✅ Verificar asiento marcado como ocupado
4. ✅ Intentar vender mismo asiento (debe fallar)
5. ✅ Cambiar fecha y verificar asientos libres
6. ✅ Probar como Secretaria (sin campo valor)
7. ✅ Probar como Admin (con campo valor editable)
8. ✅ Verificar auto-scroll al presionar Enter
9. ✅ Seleccionar asiento desde mapa visual
10. ✅ Verificar rango de fechas (hasta 5 semanas)

---

**Desarrollado para**: Suray Mini POS - Sistema de Transporte de Pasajeros
**Fecha**: Noviembre 2025
**Versión**: 2.0.0
