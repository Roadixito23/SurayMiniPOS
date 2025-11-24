class Tarifa {
  final int? id;
  final String tipoDia; // "LUNES A SÁBADO" o "DOMINGO / FERIADO"
  final String categoria; // "PUBLICO GENERAL", "ESCOLAR", "ADULTO MAYOR", "INTERMEDIO 15KM", etc.
  final double valor;
  final bool activo;
  final String? color; // Color en formato HEX (ej: "FF4286F4")

  Tarifa({
    this.id,
    required this.tipoDia,
    required this.categoria,
    required this.valor,
    this.activo = true,
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo_dia': tipoDia,
      'categoria': categoria,
      'valor': valor,
      'activo': activo ? 1 : 0,
      'color': color,
    };
  }

  factory Tarifa.fromMap(Map<String, dynamic> map) {
    return Tarifa(
      id: map['id'] as int?,
      tipoDia: map['tipo_dia'] as String,
      categoria: map['categoria'] as String,
      valor: (map['valor'] as num).toDouble(),
      activo: (map['activo'] as int) == 1,
      color: map['color'] as String?,
    );
  }

  Tarifa copyWith({
    int? id,
    String? tipoDia,
    String? categoria,
    double? valor,
    bool? activo,
    String? color,
  }) {
    return Tarifa(
      id: id ?? this.id,
      tipoDia: tipoDia ?? this.tipoDia,
      categoria: categoria ?? this.categoria,
      valor: valor ?? this.valor,
      activo: activo ?? this.activo,
      color: color ?? this.color,
    );
  }

  // Método para obtener el título corto de la categoría para el PDF
  String getTituloCorto() {
    if (categoria.contains('INTERMEDIO')) {
      return 'INTERMEDIO';
    }
    return categoria;
  }

  // Método para obtener el detalle de kilómetros si es intermedio
  String? getDetalleKm() {
    if (categoria.contains('15KM')) {
      return '15';
    } else if (categoria.contains('50KM')) {
      return '50';
    }
    return null;
  }
}
