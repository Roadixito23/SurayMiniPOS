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
      version: 1,
      onCreate: _createDB,
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
  Future close() async {
    final db = await database;
    db.close();
  }
}
