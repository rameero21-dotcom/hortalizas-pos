import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';

/// Helper central de SQLite: crea y versiona el esquema local.
/// Toda la app trabaja "offline-first" contra esta base; el SyncService
/// se encarga de reflejar los cambios en Firestore cuando hay conexión.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'hortalizas_pos.db');
    return openDatabase(
      path,
      version: 13,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Migra instalaciones existentes: agrega columnas de costo/impuestos a
  /// productos y las tablas de caja (v1->v2), nombreCliente/pagos
  /// múltiples en ventas (v2->v3), y vendedorNombre en ventas (v3->v4).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE ${AppConstants.tablaProductos} ADD COLUMN costoUnitario REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE ${AppConstants.tablaProductos} ADD COLUMN tasaIIBB REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE ${AppConstants.tablaProductos} ADD COLUMN tasaTSH REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE ${AppConstants.tablaVentas} ADD COLUMN clienteId TEXT');
      await _crearTablasCaja(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE ${AppConstants.tablaVentas} ADD COLUMN nombreCliente TEXT');
      await db.execute('ALTER TABLE ${AppConstants.tablaVentas} ADD COLUMN pagos TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE ${AppConstants.tablaVentas} ADD COLUMN vendedorNombre TEXT');
    }
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE movimientos_caja ADD COLUMN metodo TEXT NOT NULL DEFAULT 'efectivo'");
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE ${AppConstants.tablaProductos} ADD COLUMN fechaCreacion TEXT');
    }
    if (oldVersion < 7) {
      // Ya crea la tabla con saldoCuentaCorriente incluido (ver abajo),
      // así que folks migrando desde antes de la v7 no necesitan el
      // ALTER TABLE de más abajo.
      await _crearTablasProveedores(db);
    } else if (oldVersion == 7) {
      // Ya tenían la tabla de proveedores (sin saldo) de la v7 exacta.
      await db.execute(
          'ALTER TABLE ${AppConstants.tablaProveedores} ADD COLUMN saldoCuentaCorriente REAL NOT NULL DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pagos_proveedor (
          id TEXT PRIMARY KEY,
          proveedorId TEXT NOT NULL,
          monto REAL NOT NULL,
          metodoPago TEXT NOT NULL,
          fecha TEXT NOT NULL,
          usuarioId TEXT NOT NULL,
          nota TEXT
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute("ALTER TABLE ${AppConstants.tablaClientes} ADD COLUMN cuitODni TEXT NOT NULL DEFAULT ''");
      await db.execute('ALTER TABLE ${AppConstants.tablaClientes} ADD COLUMN condicionFiscal TEXT');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE ${AppConstants.tablaVentas} ADD COLUMN cuitDniComprador TEXT');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE movimientos_cuenta_corriente ADD COLUMN metodoPago TEXT');
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS facturacion_marcados (
          id TEXT PRIMARY KEY,
          fechaMarcado TEXT NOT NULL,
          usuarioId TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS facturacion_ocultos (
          id TEXT PRIMARY KEY,
          fechaOculto TEXT NOT NULL,
          usuarioId TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _crearTablasProveedores(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tablaProveedores} (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        telefono TEXT NOT NULL DEFAULT '',
        activo INTEGER NOT NULL DEFAULT 1,
        saldoCuentaCorriente REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tablaPedidosProveedor} (
        id TEXT PRIMARY KEY,
        proveedorId TEXT NOT NULL,
        productoId TEXT,
        productoNombre TEXT NOT NULL,
        cantidad REAL NOT NULL,
        metodoPago TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        usuarioId TEXT NOT NULL,
        nota TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pagos_proveedor (
        id TEXT PRIMARY KEY,
        proveedorId TEXT NOT NULL,
        monto REAL NOT NULL,
        metodoPago TEXT NOT NULL,
        fecha TEXT NOT NULL,
        usuarioId TEXT NOT NULL,
        nota TEXT
      )
    ''');
  }

  Future<void> _crearTablasCaja(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimientos_caja (
        id TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        monto REAL NOT NULL,
        detalle TEXT NOT NULL,
        fecha TEXT NOT NULL,
        usuarioId TEXT NOT NULL,
        metodo TEXT NOT NULL DEFAULT 'efectivo'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cierres_caja (
        id TEXT PRIMARY KEY,
        fecha TEXT NOT NULL,
        cajaInicio REAL NOT NULL DEFAULT 0,
        billetesJson TEXT NOT NULL,
        usuarioId TEXT NOT NULL,
        nota TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimientos_cuenta_corriente (
        id TEXT PRIMARY KEY,
        clienteId TEXT NOT NULL,
        tipo TEXT NOT NULL,
        monto REAL NOT NULL,
        detalle TEXT NOT NULL,
        fecha TEXT NOT NULL,
        usuarioId TEXT NOT NULL,
        metodoPago TEXT
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tablaProductos} (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        precioSugerido REAL NOT NULL DEFAULT 0,
        categoria TEXT NOT NULL DEFAULT '',
        activo INTEGER NOT NULL DEFAULT 1,
        favorito INTEGER NOT NULL DEFAULT 0,
        costoUnitario REAL NOT NULL DEFAULT 0,
        tasaIIBB REAL NOT NULL DEFAULT 0,
        tasaTSH REAL NOT NULL DEFAULT 0,
        fechaCreacion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tablaVentas} (
        id TEXT PRIMARY KEY,
        numero INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        vendedorId TEXT NOT NULL,
        vendedorNombre TEXT,
        total REAL NOT NULL,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        metodoPago TEXT,
        cajeroId TEXT,
        fechaCobro TEXT,
        clienteId TEXT,
        nombreCliente TEXT,
        pagos TEXT,
        cuitDniComprador TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tablaDetalleVenta} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ventaId TEXT NOT NULL,
        productoId TEXT NOT NULL,
        nombreProducto TEXT NOT NULL,
        cantidad REAL NOT NULL,
        precioTotal REAL NOT NULL,
        FOREIGN KEY (ventaId) REFERENCES ${AppConstants.tablaVentas}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tablaStock} (
        productoId TEXT PRIMARY KEY,
        cantidadDisponible REAL NOT NULL DEFAULT 0,
        umbralStockBajo REAL NOT NULL DEFAULT ${AppConstants.umbralStockBajoDefault}
      )
    ''');

    await db.execute('''
      CREATE TABLE movimientos_stock (
        id TEXT PRIMARY KEY,
        productoId TEXT NOT NULL,
        tipo TEXT NOT NULL,
        cantidad REAL NOT NULL,
        fecha TEXT NOT NULL,
        usuarioId TEXT NOT NULL,
        nota TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tablaUsuarios} (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        email TEXT NOT NULL,
        rol TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tablaClientes} (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        telefono TEXT,
        direccion TEXT,
        saldoCuentaCorriente REAL NOT NULL DEFAULT 0,
        cuitODni TEXT NOT NULL DEFAULT '',
        condicionFiscal TEXT
      )
    ''');

    // Cola de sincronización: cada fila es un cambio pendiente de subir a Firestore.
    await db.execute('''
      CREATE TABLE ${AppConstants.tablaSyncQueue} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entidad TEXT NOT NULL,
        entidadId TEXT NOT NULL,
        operacion TEXT NOT NULL,
        payload TEXT NOT NULL,
        fechaCreacion TEXT NOT NULL,
        intentos INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _crearTablasCaja(db);
    await _crearTablasProveedores(db);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS facturacion_marcados (
        id TEXT PRIMARY KEY,
        fechaMarcado TEXT NOT NULL,
        usuarioId TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS facturacion_ocultos (
        id TEXT PRIMARY KEY,
        fechaOculto TEXT NOT NULL,
        usuarioId TEXT NOT NULL
      )
    ''');

    await _seedDatosIniciales(db);
  }

  /// Carga inicial: productos base (papa, batata, cebolla, etc.) con su
  /// fila de stock en 0, y usuarios demo (uno por rol) para poder probar
  /// la app antes de tener Firebase Auth conectado (Fase 2).
  ///
  /// IMPORTANTE: los usuarios demo no tienen login real todavía (Fase 2);
  /// solo sirven para tener IDs válidos de vendedorId/cajeroId mientras
  /// se prueba el flujo de venta localmente.
  Future<void> _seedDatosIniciales(Database db) async {
    final uuid = Uuid();

    final nombresProductos = [
      'Papa',
      'Batata',
      'Cebolla',
      'Zanahoria',
      'Anco',
      'Cautiá',
      'Ajo',
    ];

    final batch = db.batch();
    for (final nombre in nombresProductos) {
      final id = uuid.v4();
      batch.insert(AppConstants.tablaProductos, {
        'id': id,
        'nombre': nombre,
        'precioSugerido': 0,
        'categoria': 'Verduras',
        'activo': 1,
        'favorito': 0,
      });
      batch.insert(AppConstants.tablaStock, {
        'productoId': id,
        'cantidadDisponible': 0,
        'umbralStockBajo': AppConstants.umbralStockBajoDefault,
      });
    }

    // Usuarios demo (Fase 1, sin autenticación real todavía).
    batch.insert(AppConstants.tablaUsuarios, {
      'id': 'demo-vendedor',
      'nombre': 'Vendedor Demo',
      'email': 'vendedor@demo.com',
      'rol': 'vendedor',
      'activo': 1,
    });
    batch.insert(AppConstants.tablaUsuarios, {
      'id': 'demo-cajero',
      'nombre': 'Cajero Demo',
      'email': 'cajero@demo.com',
      'rol': 'cajero',
      'activo': 1,
    });
    batch.insert(AppConstants.tablaUsuarios, {
      'id': 'demo-admin',
      'nombre': 'Administrador Demo',
      'email': 'admin@demo.com',
      'rol': 'administrador',
      'activo': 1,
    });

    await batch.commit(noResult: true);
  }
}
