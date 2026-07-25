import '../../core/constants/app_constants.dart';
import '../../domain/entities/cliente.dart';
import '../../domain/repositories/cliente_repository.dart';
import '../datasources/local/cliente_local_datasource.dart';
import '../datasources/local/sync_queue_local_datasource.dart';
import '../models/cliente_model.dart';

class ClienteRepositoryImpl implements ClienteRepository {
  final ClienteLocalDatasource _local;
  final SyncQueueLocalDatasource _syncQueue;

  ClienteRepositoryImpl(this._local, this._syncQueue);

  ClienteModel _toModel(Cliente c) => ClienteModel(
        id: c.id,
        nombre: c.nombre,
        telefono: c.telefono,
        direccion: c.direccion,
        saldoCuentaCorriente: c.saldoCuentaCorriente,
      );

  @override
  Future<List<Cliente>> obtenerTodos() => _local.obtenerTodos();

  @override
  Future<Cliente?> obtenerPorId(String id) async {
    final todos = await _local.obtenerTodos();
    try {
      return todos.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> crear(Cliente cliente) async {
    final model = _toModel(cliente);
    await _local.upsert(model);
    await _syncQueue.encolar(
      entidad: AppConstants.colClientes,
      entidadId: model.id,
      operacion: 'set',
      payload: model.toMap(),
    );
  }

  @override
  Future<void> actualizar(Cliente cliente) => crear(cliente);

  @override
  Future<void> eliminar(String id) async {
    await _local.eliminar(id);
    await _syncQueue.encolar(
      entidad: AppConstants.colClientes,
      entidadId: id,
      operacion: 'delete',
      payload: const {},
    );
  }
}
