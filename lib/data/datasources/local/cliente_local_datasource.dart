import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/cliente_model.dart';
import 'database_helper.dart';

class ClienteLocalDatasource {
  final DatabaseHelper _dbHelper;
  ClienteLocalDatasource(this._dbHelper);

  Future<List<ClienteModel>> obtenerTodos() async {
    final db = await _dbHelper.database;
    final rows = await db.query(AppConstants.tablaClientes);
    return rows.map(ClienteModel.fromMap).toList();
  }

  Future<void> upsert(ClienteModel cliente) async {
    final db = await _dbHelper.database;
    await db.insert(
      AppConstants.tablaClientes,
      cliente.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> eliminar(String id) async {
    final db = await _dbHelper.database;
    await db.delete(AppConstants.tablaClientes, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> actualizarSaldo(String clienteId, double nuevoSaldo) async {
    final db = await _dbHelper.database;
    await db.update(
      AppConstants.tablaClientes,
      {'saldoCuentaCorriente': nuevoSaldo},
      where: 'id = ?',
      whereArgs: [clienteId],
    );
  }

  Future<void> registrarMovimientoCuenta(MovimientoCuentaCorrienteModel movimiento) async {
    final db = await _dbHelper.database;
    await db.insert(
      'movimientos_cuenta_corriente',
      movimiento.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MovimientoCuentaCorrienteModel>> obtenerMovimientosCuenta(String clienteId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'movimientos_cuenta_corriente',
      where: 'clienteId = ?',
      whereArgs: [clienteId],
      orderBy: 'fecha DESC',
    );
    return rows.map(MovimientoCuentaCorrienteModel.fromMap).toList();
  }
}
