import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('suray_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        rol TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        id_secretario TEXT,
        sucursal_origen TEXT
      )
    ''');

    // Tabla de configuración del sistema
    await db.execute('''
      CREATE TABLE configuracion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clave TEXT NOT NULL UNIQUE,
        valor TEXT NOT NULL
      )
    ''');

    // Tabla de tarifas
    await db.execute('''
      CREATE TABLE tarifas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo_dia TEXT NOT NULL,
        categoria TEXT NOT NULL,
        valor REAL NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabla de horarios
    await db.execute('''
      CREATE TABLE horarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        horario TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        orden INTEGER NOT NULL
      )
    ''');

    // Tabla de salidas de bus
    await db.execute('''
      CREATE TABLE salidas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        horario TEXT NOT NULL,
        destino TEXT NOT NULL,
        tipo_dia TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        UNIQUE(fecha, horario, destino)
      )
    ''');

    // Tabla de asientos reservados
    await db.execute('''
      CREATE TABLE asientos_reservados (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        salida_id INTEGER NOT NULL,
        numero_asiento INTEGER NOT NULL,
        comprobante TEXT,
        fecha_reserva TEXT NOT NULL,
        FOREIGN KEY (salida_id) REFERENCES salidas (id) ON DELETE CASCADE,
        UNIQUE(salida_id, numero_asiento)
      )
    ''');

    // Tabla de boletos vendidos (historial completo)
    await db.execute('''
      CREATE TABLE boletos_vendidos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        comprobante TEXT NOT NULL UNIQUE,
        tipo TEXT NOT NULL,
        fecha_venta TEXT NOT NULL,
        hora_venta TEXT NOT NULL,
        fecha_salida TEXT,
        hora_salida TEXT,
        destino TEXT,
        asiento INTEGER,
        valor REAL NOT NULL,
        id_vendedor TEXT NOT NULL,
        sucursal TEXT NOT NULL,
        usuario TEXT NOT NULL,
        datos_completos TEXT NOT NULL,
        anulado INTEGER NOT NULL DEFAULT 0,
        fecha_anulacion TEXT,
        hora_anulacion TEXT,
        usuario_anulacion TEXT,
        motivo_anulacion TEXT
      )
    ''');

    // Insertar usuario administrador por defecto
    await db.insert('usuarios', {
      'username': 'admin',
      'password': 'admin', // Contraseña plana como solicitado
      'rol': 'Administrador',
      'activo': 1,
      'fecha_creacion': DateTime.now().toIso8601String(),
      'id_secretario': '01',
      'sucursal_origen': 'AYS',
    });

    // Insertar configuración por defecto
    await db.insert('configuracion', {'clave': 'origen', 'valor': 'AYS'});
    await db.insert('configuracion', {'clave': 'id_usuario', 'valor': '01'});
    await db.insert('configuracion', {'clave': 'serie', 'valor': '000001'});

    // Insertar tarifas por defecto - Lunes a Sábado
    await db.insert('tarifas', {
      'tipo_dia': 'LUNES A SÁBADO',
      'categoria': 'PUBLICO GENERAL',
      'valor': 3600.0,
      'activo': 1,
    });
    await db.insert('tarifas', {
      'tipo_dia': 'LUNES A SÁBADO',
      'categoria': 'ESCOLAR',
      'valor': 2500.0,
      'activo': 1,
    });
    await db.insert('tarifas', {
      'tipo_dia': 'LUNES A SÁBADO',
      'categoria': 'ADULTO MAYOR',
      'valor': 1800.0,
      'activo': 1,
    });
    await db.insert('tarifas', {
      'tipo_dia': 'LUNES A SÁBADO',
      'categoria': 'INTERMEDIO 15KM',
      'valor': 1800.0,
      'activo': 1,
    });
    await db.insert('tarifas', {
      'tipo_dia': 'LUNES A SÁBADO',
      'categoria': 'INTERMEDIO 50KM',
      'valor': 2500.0,
      'activo': 1,
    });

    // Insertar tarifas por defecto - Domingo o Feriado
    await db.insert('tarifas', {
      'tipo_dia': 'DOMINGO / FERIADO',
      'categoria': 'PUBLICO GENERAL',
      'valor': 4300.0,
      'activo': 1,
    });
    await db.insert('tarifas', {
      'tipo_dia': 'DOMINGO / FERIADO',
      'categoria': 'ESCOLAR',
      'valor': 3000.0,
      'activo': 1,
    });
    await db.insert('tarifas', {
      'tipo_dia': 'DOMINGO / FERIADO',
      'categoria': 'ADULTO MAYOR',
      'valor': 2150.0,
      'activo': 1,
    });
    await db.insert('tarifas', {
      'tipo_dia': 'DOMINGO / FERIADO',
      'categoria': 'INTERMEDIO',
      'valor': 3000.0,
      'activo': 1,
    });
  }

  // MÉTODOS PARA USUARIOS
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    final result = await db.query(
      'usuarios',
      where: 'username = ? AND password = ? AND activo = 1',
      whereArgs: [username, password],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllUsuarios() async {
    final db = await database;
    return await db.query('usuarios', orderBy: 'username ASC');
  }

  Future<int> insertUsuario(Map<String, dynamic> usuario) async {
    final db = await database;
    return await db.insert('usuarios', usuario);
  }

  Future<int> updateUsuario(int id, Map<String, dynamic> usuario) async {
    final db = await database;
    return await db.update(
      'usuarios',
      usuario,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteUsuario(int id) async {
    final db = await database;
    return await db.update(
      'usuarios',
      {'activo': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarUsuarioPermanente(int id) async {
    final db = await database;
    return await db.delete(
      'usuarios',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Validar si ID de secretario ya existe en una sucursal
  Future<bool> idSecretarioDisponible(String idSecretario, String sucursal, {int? excluyendoUsuarioId}) async {
    final db = await database;
    final whereClause = excluyendoUsuarioId != null
        ? 'id_secretario = ? AND sucursal_origen = ? AND id != ?'
        : 'id_secretario = ? AND sucursal_origen = ?';
    final whereArgs = excluyendoUsuarioId != null
        ? [idSecretario, sucursal, excluyendoUsuarioId]
        : [idSecretario, sucursal];

    final result = await db.query(
      'usuarios',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return result.isEmpty;
  }

  // MÉTODOS PARA CONFIGURACIÓN
  Future<String?> getConfiguracion(String clave) async {
    final db = await database;
    final result = await db.query(
      'configuracion',
      where: 'clave = ?',
      whereArgs: [clave],
    );

    if (result.isNotEmpty) {
      return result.first['valor'] as String;
    }
    return null;
  }

  Future<int> setConfiguracion(String clave, String valor) async {
    final db = await database;
    final existing = await db.query(
      'configuracion',
      where: 'clave = ?',
      whereArgs: [clave],
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'configuracion',
        {'valor': valor},
        where: 'clave = ?',
        whereArgs: [clave],
      );
    } else {
      return await db.insert('configuracion', {'clave': clave, 'valor': valor});
    }
  }

  Future<Map<String, String>> getAllConfiguracion() async {
    final db = await database;
    final result = await db.query('configuracion');
    return Map.fromEntries(
      result.map((row) => MapEntry(row['clave'] as String, row['valor'] as String)),
    );
  }

  // MÉTODOS PARA TARIFAS
  Future<List<Map<String, dynamic>>> getTarifasByTipoDia(String tipoDia) async {
    final db = await database;
    return await db.query(
      'tarifas',
      where: 'tipo_dia = ? AND activo = 1',
      whereArgs: [tipoDia],
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllTarifas() async {
    final db = await database;
    return await db.query('tarifas', where: 'activo = 1', orderBy: 'tipo_dia, id ASC');
  }

  Future<int> insertTarifa(Map<String, dynamic> tarifa) async {
    final db = await database;
    return await db.insert('tarifas', tarifa);
  }

  Future<int> updateTarifa(int id, Map<String, dynamic> tarifa) async {
    final db = await database;
    return await db.update(
      'tarifas',
      tarifa,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTarifa(int id) async {
    final db = await database;
    return await db.update(
      'tarifas',
      {'activo': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MÉTODOS PARA HORARIOS
  Future<List<Map<String, dynamic>>> getAllHorarios() async {
    final db = await database;
    return await db.query('horarios', where: 'activo = 1', orderBy: 'orden ASC');
  }

  Future<int> insertHorario(String horario, int orden) async {
    final db = await database;
    return await db.insert('horarios', {
      'horario': horario,
      'activo': 1,
      'orden': orden,
    });
  }

  Future<int> updateHorario(int id, String horario, int orden) async {
    final db = await database;
    return await db.update(
      'horarios',
      {'horario': horario, 'orden': orden},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteHorario(int id) async {
    final db = await database;
    return await db.update(
      'horarios',
      {'activo': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Cerrar la base de datos
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar tablas de salidas y asientos reservados
      await db.execute('''
        CREATE TABLE salidas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha TEXT NOT NULL,
          horario TEXT NOT NULL,
          destino TEXT NOT NULL,
          tipo_dia TEXT NOT NULL,
          activo INTEGER NOT NULL DEFAULT 1,
          UNIQUE(fecha, horario, destino)
        )
      ''');

      await db.execute('''
        CREATE TABLE asientos_reservados (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          salida_id INTEGER NOT NULL,
          numero_asiento INTEGER NOT NULL,
          comprobante TEXT,
          fecha_reserva TEXT NOT NULL,
          FOREIGN KEY (salida_id) REFERENCES salidas (id) ON DELETE CASCADE,
          UNIQUE(salida_id, numero_asiento)
        )
      ''');
    }

    if (oldVersion < 3) {
      // Agregar campos id_secretario y sucursal_origen a usuarios
      await db.execute('ALTER TABLE usuarios ADD COLUMN id_secretario TEXT');
      await db.execute('ALTER TABLE usuarios ADD COLUMN sucursal_origen TEXT');

      // Actualizar usuarios existentes con valores por defecto
      await db.execute('''
        UPDATE usuarios
        SET id_secretario = '01', sucursal_origen = 'AYS'
        WHERE id_secretario IS NULL
      ''');
    }

    if (oldVersion < 4) {
      // Agregar tabla de boletos vendidos
      await db.execute('''
        CREATE TABLE boletos_vendidos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          comprobante TEXT NOT NULL UNIQUE,
          tipo TEXT NOT NULL,
          fecha_venta TEXT NOT NULL,
          hora_venta TEXT NOT NULL,
          fecha_salida TEXT,
          hora_salida TEXT,
          destino TEXT,
          asiento INTEGER,
          valor REAL NOT NULL,
          id_vendedor TEXT NOT NULL,
          sucursal TEXT NOT NULL,
          usuario TEXT NOT NULL,
          datos_completos TEXT NOT NULL,
          anulado INTEGER NOT NULL DEFAULT 0,
          fecha_anulacion TEXT,
          hora_anulacion TEXT,
          usuario_anulacion TEXT,
          motivo_anulacion TEXT
        )
      ''');
    }
  }

  // MÉTODOS PARA SALIDAS
  Future<int> crearObtenerSalida({
    required String fecha,
    required String horario,
    required String destino,
    required String tipoDia,
  }) async {
    final db = await database;

    // Buscar si ya existe la salida
    final result = await db.query(
      'salidas',
      where: 'fecha = ? AND horario = ? AND destino = ? AND activo = 1',
      whereArgs: [fecha, horario, destino],
    );

    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }

    // Crear nueva salida
    return await db.insert('salidas', {
      'fecha': fecha,
      'horario': horario,
      'destino': destino,
      'tipo_dia': tipoDia,
      'activo': 1,
    });
  }

  Future<List<Map<String, dynamic>>> getAsientosOcupados(int salidaId) async {
    final db = await database;
    return await db.query(
      'asientos_reservados',
      where: 'salida_id = ?',
      whereArgs: [salidaId],
      orderBy: 'numero_asiento ASC',
    );
  }

  Future<int> reservarAsiento({
    required int salidaId,
    required int numeroAsiento,
    String? comprobante,
  }) async {
    final db = await database;
    return await db.insert('asientos_reservados', {
      'salida_id': salidaId,
      'numero_asiento': numeroAsiento,
      'comprobante': comprobante,
      'fecha_reserva': DateTime.now().toIso8601String(),
    });
  }

  Future<int> liberarAsiento(int salidaId, int numeroAsiento) async {
    final db = await database;
    return await db.delete(
      'asientos_reservados',
      where: 'salida_id = ? AND numero_asiento = ?',
      whereArgs: [salidaId, numeroAsiento],
    );
  }

  Future<List<Map<String, dynamic>>> getSalidasEnRango({
    required String fechaInicio,
    required String fechaFin,
  }) async {
    final db = await database;
    return await db.query(
      'salidas',
      where: 'fecha >= ? AND fecha <= ? AND activo = 1',
      whereArgs: [fechaInicio, fechaFin],
      orderBy: 'fecha ASC, horario ASC',
    );
  }

  // Limpiar todas las tablas (excepto usuarios y configuración básica)
  Future<void> limpiarTodasLasTablas() async {
    final db = await database;

    // Eliminar datos de ventas y operaciones
    await db.delete('asientos_reservados');
    await db.delete('salidas');

    // Si existen otras tablas de transacciones, eliminarlas también
    // await db.delete('comprobantes'); // Descomentar si existe
    // await db.delete('cierres_caja'); // Descomentar si existe
  }

  // MÉTODOS PARA BOLETOS VENDIDOS

  /// Inserta un nuevo boleto vendido en el historial
  Future<int> insertarBoleto({
    required String comprobante,
    required String tipo,
    required String fechaVenta,
    required String horaVenta,
    String? fechaSalida,
    String? horaSalida,
    String? destino,
    int? asiento,
    required double valor,
    required String idVendedor,
    required String sucursal,
    required String usuario,
    required String datosCompletos,
  }) async {
    final db = await database;
    return await db.insert('boletos_vendidos', {
      'comprobante': comprobante,
      'tipo': tipo,
      'fecha_venta': fechaVenta,
      'hora_venta': horaVenta,
      'fecha_salida': fechaSalida,
      'hora_salida': horaSalida,
      'destino': destino,
      'asiento': asiento,
      'valor': valor,
      'id_vendedor': idVendedor,
      'sucursal': sucursal,
      'usuario': usuario,
      'datos_completos': datosCompletos,
      'anulado': 0,
    });
  }

  /// Obtiene boletos con filtros opcionales
  Future<List<Map<String, dynamic>>> getBoletos({
    String? fechaInicio,
    String? fechaFin,
    String? sucursal,
    String? idVendedor,
    String? comprobante,
    bool? soloActivos,
    int? limit,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (fechaInicio != null && fechaFin != null) {
      whereClause += ' AND fecha_venta >= ? AND fecha_venta <= ?';
      whereArgs.addAll([fechaInicio, fechaFin]);
    }

    if (sucursal != null) {
      whereClause += ' AND sucursal = ?';
      whereArgs.add(sucursal);
    }

    if (idVendedor != null) {
      whereClause += ' AND id_vendedor = ?';
      whereArgs.add(idVendedor);
    }

    if (comprobante != null) {
      whereClause += ' AND comprobante LIKE ?';
      whereArgs.add('%$comprobante%');
    }

    if (soloActivos == true) {
      whereClause += ' AND anulado = 0';
    }

    return await db.query(
      'boletos_vendidos',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'fecha_venta DESC, hora_venta DESC',
      limit: limit,
    );
  }

  /// Busca un boleto por su comprobante
  Future<Map<String, dynamic>?> buscarBoletoPorComprobante(String comprobante) async {
    final db = await database;
    final result = await db.query(
      'boletos_vendidos',
      where: 'comprobante = ?',
      whereArgs: [comprobante],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  /// Verifica si un boleto puede ser anulado (más de 4 horas antes de la salida)
  Future<bool> verificarBoletoAnulable(String comprobante) async {
    final boleto = await buscarBoletoPorComprobante(comprobante);

    if (boleto == null) return false;
    if (boleto['anulado'] == 1) return false;
    if (boleto['tipo'] != 'bus') return true; // Carga se puede anular siempre

    // Para boletos de bus, verificar que falten más de 4 horas
    final fechaSalida = boleto['fecha_salida'] as String?;
    final horaSalida = boleto['hora_salida'] as String?;

    if (fechaSalida == null || horaSalida == null) return true;

    try {
      final fechaHoraSalida = DateTime.parse('$fechaSalida $horaSalida');
      final ahora = DateTime.now();
      final diferencia = fechaHoraSalida.difference(ahora);

      // Debe faltar más de 4 horas
      return diferencia.inHours >= 4;
    } catch (e) {
      return true; // En caso de error, permitir anulación
    }
  }

  /// Anula un boleto
  Future<int> anularBoleto({
    required String comprobante,
    required String usuario,
    required String motivo,
  }) async {
    final db = await database;
    final ahora = DateTime.now();

    return await db.update(
      'boletos_vendidos',
      {
        'anulado': 1,
        'fecha_anulacion': ahora.toString().split(' ')[0],
        'hora_anulacion': ahora.toString().split(' ')[1].substring(0, 8),
        'usuario_anulacion': usuario,
        'motivo_anulacion': motivo,
      },
      where: 'comprobante = ?',
      whereArgs: [comprobante],
    );
  }

  /// Limpia boletos expirados (salidas pasadas o próximas a expirar en 4 horas)
  Future<int> limpiarBoletosExpirados() async {
    final db = await database;
    final ahora = DateTime.now();
    final limiteExpiracion = ahora.add(Duration(hours: 4));

    final fechaActual = ahora.toString().split(' ')[0];
    final horaActual = ahora.toString().split(' ')[1].substring(0, 8);
    final fechaLimite = limiteExpiracion.toString().split(' ')[0];
    final horaLimite = limiteExpiracion.toString().split(' ')[1].substring(0, 8);

    // Eliminar boletos de bus cuya salida ya pasó o está próxima a pasar (4 horas)
    // Solo elimina boletos activos (no anulados) para mantener historial de anulaciones
    return await db.delete(
      'boletos_vendidos',
      where: '''
        tipo = 'bus' AND anulado = 0 AND (
          (fecha_salida < ?) OR
          (fecha_salida = ? AND hora_salida < ?) OR
          (fecha_salida = ? AND hora_salida <= ? AND fecha_salida <= ?)
        )
      ''',
      whereArgs: [
        fechaActual,
        fechaActual,
        horaActual,
        fechaLimite,
        horaLimite,
        fechaLimite,
      ],
    );
  }

  /// Cuenta boletos anulados por un usuario en una fecha específica
  Future<int> contarAnulacionesUsuario(String usuario, String fecha) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM boletos_vendidos WHERE usuario_anulacion = ? AND fecha_anulacion = ?',
      [usuario, fecha],
    );

    return result.first['total'] as int? ?? 0;
  }

  // Cerrar la base de datos
  Future close() async {
    final db = await database;
    db.close();
  }
}
