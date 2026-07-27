import '../../core/constants/app_constants.dart';
import '../../domain/entities/producto.dart';
import '../../domain/repositories/producto_repository.dart';
import '../datasources/local/producto_local_datasource.dart';
import '../datasources/local/sync_queue_local_datasource.dart';
import '../datasources/remote/producto_remote_datasource.dart';
import '../models/producto_model.dart';

/// Implementación offline-first: SQLite es la fuente de verdad local;
/// cada escritura encola el cambio para que SyncService lo suba a
/// Firestore apenas haya conexión.
class ProductoRepositoryImpl implements ProductoRepository {
  final ProductoLocalDatasource _local;
  final SyncQueueLocalDatasource _syncQueue;
  final ProductoRemoteDatasource _remote;

  ProductoRepositoryImpl(this._local, this._syncQueue, this._remote);

  @override
  Future<List<Producto>> obtenerTodos() => _local.obtenerTodos();

  @override
  Future<List<Producto>> buscar(String query) => _local.buscar(query);

  @override
  Future<Producto?> obtenerPorId(String id) async {
    final todos = await _local.obtenerTodos();
    try {
      return todos.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> crear(Producto producto) async {
    final model = ProductoModel.fromEntity(producto);
    await _local.upsert(model);
    await _syncQueue.encolar(
      entidad: AppConstants.colProductos,
      entidadId: model.id,
      operacion: 'set',
      payload: model.toMap(),
    );
  }

  @override
  Future<void> actualizar(Producto producto) => crear(producto); // mismo upsert + encolado

  @override
  Future<void> eliminar(String id) async {
    await _local.eliminar(id);
    await _syncQueue.encolar(
      entidad: AppConstants.colProductos,
      entidadId: id,
      operacion: 'delete',
      payload: const {},
    );
  }

  @override
  Stream<List<Producto>> observarTodos() {
    // TODO Fase 3+: combinar snapshot local (polling/stream sqflite) con remoto
    // si se necesita reflejar en tiempo real productos creados desde otro
    // dispositivo/admin. Por ahora, la pantalla debe releer con obtenerTodos().
    throw UnimplementedError('observarTodos - pendiente de stream local/remoto');
  }

  @override
  Future<void> refrescarDesdeRemoto() async {
    try {
      final remotos = await _remote.obtenerTodos();
      for (final producto in remotos) {
        await _local.upsert(producto);
      }
    } catch (_) {
      // Sin conexión o error de red: la app sigue con lo que ya tenía
      // en la caché local, no hace falta romper la pantalla por esto.
    }
  }
}
