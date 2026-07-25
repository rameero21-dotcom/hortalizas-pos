import '../../../core/constants/app_constants.dart';
import '../../models/stock_model.dart';
import 'database_helper.dart';

class StockLocalDatasource {
  final DatabaseHelper _dbHelper;
  StockLocalDatasource(this._dbHelper);

  Future<StockModel?> obtenerPorProducto(String productoId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(AppConstants.tablaStock, where: 'productoId = ?', whereArgs: [productoId]);
    if (rows.isEmpty) return null;
    return StockModel.fromMap(rows.first);
  }

  Future<List<StockModel>> obtenerTodos() async {
    final db = await _dbHelper.database;
    final rows = await db.query(AppConstants.tablaStock);
    return rows.map(StockModel.fromMap).toList();
  }

  /// Actualiza la cantidad de stock de un producto. Si el producto todavía
  /// no tiene fila en la tabla de stock (ej: se creó después de la siembra
  /// inicial, desde Admin > Productos), la crea con el umbral por defecto
  /// en vez de fallar silenciosamente (un UPDATE sin filas coincidentes no
  /// tira error en SQLite, así que sin este chequeo la cantidad se perdía).
  Future<void> actualizarCantidad(String productoId, double nuevaCantidad) async {
    final db = await _dbHelper.database;
    final filasActualizadas = await db.update(
      AppConstants.tablaStock,
      {'cantidadDisponible': nuevaCantidad},
      where: 'productoId = ?',
      whereArgs: [productoId],
    );
    if (filasActualizadas == 0) {
      await db.insert(AppConstants.tablaStock, {
        'productoId': productoId,
        'cantidadDisponible': nuevaCantidad,
        'umbralStockBajo': AppConstants.umbralStockBajoDefault,
      });
    }
  }

  Future<void> registrarMovimiento(MovimientoStockModel movimiento) async {
    final db = await _dbHelper.database;
    await db.insert('movimientos_stock', movimiento.toMap());
  }

  Future<List<MovimientoStockModel>> obtenerHistorial(String productoId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'movimientos_stock',
      where: 'productoId = ?',
      whereArgs: [productoId],
      orderBy: 'fecha DESC',
    );
    return rows.map(MovimientoStockModel.fromMap).toList();
  }
}
