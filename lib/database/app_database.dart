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
      version: 2,
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
        fecha_creacion TEXT NOT NULL
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

    // Insertar usuario administrador por defecto
    await db.insert('usuarios', {
      'username': 'admin',
      'password': 'admin', // Contraseña plana como solicitado
      'rol': 'Administrador',
      'activo': 1,
      'fecha_creacion': DateTime.now().toIso8601String(),
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

  // Cerrar la base de datos
  Future close() async {
    final db = await database;
    db.close();
  }
}
