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
}
