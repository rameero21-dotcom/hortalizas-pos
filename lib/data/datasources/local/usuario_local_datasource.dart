import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/usuario_model.dart';
import 'database_helper.dart';

class UsuarioLocalDatasource {
  final DatabaseHelper _dbHelper;
  UsuarioLocalDatasource(this._dbHelper);

  Future<List<UsuarioModel>> obtenerTodos() async {
    final db = await _dbHelper.database;
    final rows = await db.query(AppConstants.tablaUsuarios);
    return rows.map(UsuarioModel.fromMap).toList();
  }

  Future<void> upsert(UsuarioModel usuario) async {
    final db = await _dbHelper.database;
    await db.insert(
      AppConstants.tablaUsuarios,
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
