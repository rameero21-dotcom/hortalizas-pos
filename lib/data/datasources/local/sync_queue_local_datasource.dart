import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import 'database_helper.dart';

/// Un cambio local pendiente de subir a Firestore.
class CambioPendiente {
  final int id;
  final String entidad; // 'productos' | 'ventas' | 'stock' | 'movimientos_stock' | ...
  final String entidadId;
  final String operacion; // 'set' | 'delete'
  final Map<String, dynamic> payload;
  final int intentos;

  CambioPendiente({
    required this.id,
    required this.entidad,
    required this.entidadId,
    required this.operacion,
    required this.payload,
    required this.intentos,
  });

  factory CambioPendiente.fromMap(Map<String, dynamic> map) => CambioPendiente(
        id: map['id'] as int,
        entidad: map['entidad'] as String,
        entidadId: map['entidadId'] as String,
        operacion: map['operacion'] as String,
        payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
        intentos: map['intentos'] as int,
      );
}

/// Acceso a la tabla sync_queue: cada cambio local (crear/editar/borrar)
/// se encola acá hasta que `SyncService` logra subirlo a Firestore.
class SyncQueueLocalDatasource {
  final DatabaseHelper _dbHelper;
  SyncQueueLocalDatasource(this._dbHelper);

  Future<void> encolar({
    required String entidad,
    required String entidadId,
    required String operacion,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _dbHelper.database;
    await db.insert(AppConstants.tablaSyncQueue, {
      'entidad': entidad,
      'entidadId': entidadId,
      'operacion': operacion,
      'payload': jsonEncode(payload),
      'fechaCreacion': DateTime.now().toIso8601String(),
      'intentos': 0,
    });
  }

  Future<List<CambioPendiente>> obtenerPendientes() async {
    final db = await _dbHelper.database;
    final rows = await db.query(AppConstants.tablaSyncQueue, orderBy: 'fechaCreacion ASC');
    return rows.map(CambioPendiente.fromMap).toList();
  }

  Future<void> eliminar(int id) async {
    final db = await _dbHelper.database;
    await db.delete(AppConstants.tablaSyncQueue, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementarIntentos(int id) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      'UPDATE ${AppConstants.tablaSyncQueue} SET intentos = intentos + 1 WHERE id = ?',
      [id],
    );
  }

  /// Cuántos cambios locales todavía no se subieron a Firestore. Se usa
  /// para mostrarle al usuario un aviso si queda algo pendiente (por
  /// ejemplo, después de estar mucho tiempo sin conexión), en vez de
  /// reintentar en silencio para siempre sin que nadie se entere.
  Future<int> contarPendientes() async {
    final db = await _dbHelper.database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) as total FROM ${AppConstants.tablaSyncQueue}',
    );
    return resultado.first['total'] as int;
  }
}
