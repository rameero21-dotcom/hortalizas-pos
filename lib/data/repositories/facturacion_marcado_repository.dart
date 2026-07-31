import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/sync_service.dart';
import '../datasources/local/database_helper.dart';
import '../datasources/local/sync_queue_local_datasource.dart';
import '../datasources/remote/firestore_service.dart';

/// Maneja qué ítems de la pantalla de Facturación ya se marcaron como
/// "ya facturado" (deslizando para sacarlos de la lista). Es solo una
/// marca — NO borra la venta ni el pago real, así que el resto de la
/// app (Historial, cuenta corriente del cliente, etc.) no se ve
/// afectado para nada.
class FacturacionMarcadoRepository {
  final DatabaseHelper _dbHelper;
  final SyncQueueLocalDatasource _syncQueue;
  final FirestoreService _firestoreService;
  final SyncService _syncService;

  FacturacionMarcadoRepository(this._dbHelper, this._syncQueue, this._firestoreService, this._syncService);

  Future<void> marcarComoFacturado(String id, String usuarioId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'facturacion_marcados',
      {'id': id, 'fechaMarcado': DateTime.now().toIso8601String(), 'usuarioId': usuarioId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _syncQueue.encolar(
      entidad: AppConstants.colFacturacionMarcados,
      entidadId: id,
      operacion: 'set',
      payload: {'id': id, 'fechaMarcado': DateTime.now().toIso8601String(), 'usuarioId': usuarioId},
    );
    await _syncService.sincronizarAhora();
  }

  /// Por si alguien lo marcó por error (ej: tocó el tilde sin querer).
  Future<void> desmarcarComoFacturado(String id) async {
    final db = await _dbHelper.database;
    await db.delete('facturacion_marcados', where: 'id = ?', whereArgs: [id]);
    await _syncQueue.encolar(
      entidad: AppConstants.colFacturacionMarcados,
      entidadId: id,
      operacion: 'delete',
      payload: const {},
    );
    await _syncService.sincronizarAhora();
  }

  /// Todos los ids marcados como ya facturados, sin importar el
  /// dispositivo (para que si el admin marca uno desde el celular, no
  /// vuelva a aparecer al abrir la app desde la PC).
  Future<Set<String>> obtenerIdsMarcadosGlobal() async {
    try {
      final snap = await _firestoreService.facturacionMarcados.get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (_) {
      // Sin conexión: seguimos con la caché local (puede no estar 100%
      // al día con lo marcado desde otro dispositivo).
      final db = await _dbHelper.database;
      final rows = await db.query('facturacion_marcados');
      return rows.map((r) => r['id'] as String).toSet();
    }
  }

  /// Ocultar un ítem de la lista con el swipe (esto SÍ lo saca de la
  /// vista, a diferencia del tilde de facturado que solo lo marca sin
  /// esconderlo). Tampoco toca la venta/pago real.
  Future<void> ocultarDeFacturacion(String id, String usuarioId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'facturacion_ocultos',
      {'id': id, 'fechaOculto': DateTime.now().toIso8601String(), 'usuarioId': usuarioId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _syncQueue.encolar(
      entidad: AppConstants.colFacturacionOcultos,
      entidadId: id,
      operacion: 'set',
      payload: {'id': id, 'fechaOculto': DateTime.now().toIso8601String(), 'usuarioId': usuarioId},
    );
    await _syncService.sincronizarAhora();
  }

  Future<Set<String>> obtenerIdsOcultosGlobal() async {
    try {
      final snap = await _firestoreService.facturacionOcultos.get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (_) {
      final db = await _dbHelper.database;
      final rows = await db.query('facturacion_ocultos');
      return rows.map((r) => r['id'] as String).toSet();
    }
  }
}
