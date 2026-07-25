import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/producto_model.dart';
import 'database_helper.dart';

/// Acceso a productos en SQLite.
class ProductoLocalDatasource {
  final DatabaseHelper _dbHelper;
  ProductoLocalDatasource(this._dbHelper);

  Future<List<ProductoModel>> obtenerTodos() async {
    final db = await _dbHelper.database;
    final rows = await db.query(AppConstants.tablaProductos, orderBy: 'nombre ASC');
    return rows.map(ProductoModel.fromMap).toList();
  }

  Future<List<ProductoModel>> buscar(String query) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      AppConstants.tablaProductos,
      where: 'nombre LIKE ? AND activo = 1',
      whereArgs: ['%$query%'],
      orderBy: 'nombre ASC',
    );
    return rows.map(ProductoModel.fromMap).toList();
  }

  Future<void> upsert(ProductoModel producto) async {
    final db = await _dbHelper.database;
    await db.insert(
      AppConstants.tablaProductos,
      producto.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> eliminar(String id) async {
    final db = await _dbHelper.database;
    await db.delete(AppConstants.tablaProductos, where: 'id = ?', whereArgs: [id]);
  }
}
