import 'package:sqflite/sqflite.dart';
import '../../models/proveedor_model.dart';
import 'database_helper.dart';

class ProveedorLocalDatasource {
  final DatabaseHelper _dbHelper;
  ProveedorLocalDatasource(this._dbHelper);

  Future<List<ProveedorModel>> obtenerTodos() async {
    final db = await _dbHelper.database;
    final rows = await db.query('proveedores', orderBy: 'nombre ASC');
    return rows.map(ProveedorModel.fromMap).toList();
  }

  Future<void> upsert(ProveedorModel proveedor) async {
    final db = await _dbHelper.database;
    await db.insert('proveedores', proveedor.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> eliminar(String id) async {
    final db = await _dbHelper.database;
    await db.delete('proveedores', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PedidoProveedorModel>> obtenerPedidos(String proveedorId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'pedidos_proveedor',
      where: 'proveedorId = ?',
      whereArgs: [proveedorId],
      orderBy: 'fecha DESC',
    );
    return rows.map(PedidoProveedorModel.fromMap).toList();
  }

  Future<void> registrarPedido(PedidoProveedorModel pedido) async {
    final db = await _dbHelper.database;
    await db.insert('pedidos_proveedor', pedido.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> eliminarPedido(String id) async {
    final db = await _dbHelper.database;
    await db.delete('pedidos_proveedor', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> actualizarSaldo(String proveedorId, double nuevoSaldo) async {
    final db = await _dbHelper.database;
    await db.update('proveedores', {'saldoCuentaCorriente': nuevoSaldo},
        where: 'id = ?', whereArgs: [proveedorId]);
  }

  Future<List<PagoProveedorModel>> obtenerPagos(String proveedorId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'pagos_proveedor',
      where: 'proveedorId = ?',
      whereArgs: [proveedorId],
      orderBy: 'fecha DESC',
    );
    return rows.map(PagoProveedorModel.fromMap).toList();
  }

  Future<void> registrarPago(PagoProveedorModel pago) async {
    final db = await _dbHelper.database;
    await db.insert('pagos_proveedor', pago.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> eliminarPago(String id) async {
    final db = await _dbHelper.database;
    await db.delete('pagos_proveedor', where: 'id = ?', whereArgs: [id]);
  }
}
