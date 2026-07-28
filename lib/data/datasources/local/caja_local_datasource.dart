import 'package:sqflite/sqflite.dart';
import '../../models/caja_model.dart';
import 'database_helper.dart';

class CajaLocalDatasource {
  final DatabaseHelper _dbHelper;
  CajaLocalDatasource(this._dbHelper);

  Future<void> registrarMovimiento(MovimientoCajaModel movimiento) async {
    final db = await _dbHelper.database;
    await db.insert(
      'movimientos_caja',
      movimiento.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MovimientoCajaModel>> obtenerMovimientos(DateTime desde, DateTime hasta) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'movimientos_caja',
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [desde.toIso8601String(), hasta.toIso8601String()],
      orderBy: 'fecha DESC',
    );
    return rows.map(MovimientoCajaModel.fromMap).toList();
  }

  Future<void> eliminarMovimiento(String id) async {
    final db = await _dbHelper.database;
    await db.delete('movimientos_caja', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> guardarCierre(CierreCajaModel cierre) async {
    final db = await _dbHelper.database;
    await db.insert(
      'cierres_caja',
      cierre.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CierreCajaModel>> obtenerCierres(DateTime desde, DateTime hasta) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'cierres_caja',
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [desde.toIso8601String(), hasta.toIso8601String()],
      orderBy: 'fecha DESC',
    );
    return rows.map(CierreCajaModel.fromMap).toList();
  }
}
