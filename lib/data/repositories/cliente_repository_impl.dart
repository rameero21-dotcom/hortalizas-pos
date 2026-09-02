import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/sync_service.dart';
import '../../domain/entities/cliente.dart';
import '../../domain/entities/venta.dart' show MetodoPago;
import '../../domain/repositories/cliente_repository.dart';
import '../datasources/local/cliente_local_datasource.dart';
import '../datasources/local/sync_queue_local_datasource.dart';
import '../datasources/remote/cliente_remote_datasource.dart';
import '../models/cliente_model.dart';

class ClienteRepositoryImpl implements ClienteRepository {
  final ClienteLocalDatasource _local;
  final SyncQueueLocalDatasource _syncQueue;
  final ClienteRemoteDatasource _remote;
  final SyncService _syncService;
  final _uuid = Uuid();

  ClienteRepositoryImpl(this._local, this._syncQueue, this._remote, this._syncService);

  ClienteModel _toModel(Cliente c) => ClienteModel(
        id: c.id,
        nombre: c.nombre,
        telefono: c.telefono,
        direccion: c.direccion,
        saldoCuentaCorriente: c.saldoCuentaCorriente,
        cuitODni: c.cuitODni,
        condicionFiscal: c.condicionFiscal,
      );

  @override
  Future<List<Cliente>> obtenerTodos() => _local.obtenerTodos();

  @override
  Stream<List<Cliente>> observarTodos() => _remote.observarTodos();

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
    await _syncService.sincronizarAhora();
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
    await _syncService.sincronizarAhora();
  }

  @override
  Future<void> registrarMovimientoCuenta({
    required String clienteId,
    required TipoMovimientoCuenta tipo,
    required double monto,
    required String detalle,
    required String usuarioId,
    MetodoPago? metodoPago,
  }) async {
    final cliente = await obtenerPorId(clienteId);
    if (cliente == null) throw ArgumentError('Cliente no encontrado: $clienteId');

    // Un cargo (venta fiada) AUMENTA la deuda (el saldo se vuelve más
    // negativo); un pago la DISMINUYE (el saldo sube hacia 0 o positivo).
    final signo = tipo == TipoMovimientoCuenta.cargo ? -1 : 1;
    final nuevoSaldo = cliente.saldoCuentaCorriente + (signo * monto);
    await _local.actualizarSaldo(clienteId, nuevoSaldo);

    final movimiento = MovimientoCuentaCorrienteModel(
      id: _uuid.v4(),
      clienteId: clienteId,
      tipo: tipo,
      monto: monto,
      detalle: detalle,
      fecha: DateTime.now(),
      usuarioId: usuarioId,
      metodoPago: metodoPago,
    );
    await _local.registrarMovimientoCuenta(movimiento);

    await _syncQueue.encolar(
      entidad: AppConstants.colClientes,
      entidadId: clienteId,
      operacion: 'set',
      payload: {'id': clienteId, 'saldoCuentaCorriente': nuevoSaldo},
    );
    await _syncQueue.encolar(
      entidad: AppConstants.colMovimientosCuentaCorriente,
      entidadId: movimiento.id,
      operacion: 'set',
      payload: movimiento.toMap(),
    );
    await _syncService.sincronizarAhora();
  }

  @override
  Future<List<MovimientoCuentaCorriente>> obtenerMovimientosCuenta(String clienteId) =>
      _local.obtenerMovimientosCuenta(clienteId);

  @override
  Stream<List<MovimientoCuentaCorriente>> observarMovimientosDeCliente(String clienteId) =>
      _remote.observarMovimientosDeCliente(clienteId);

  @override
  Future<List<MovimientoCuentaCorriente>> obtenerMovimientosCuentaGlobal(DateTime desde, DateTime hasta) =>
      _remote.obtenerMovimientosPorRango(desde, hasta);

  @override
  Future<void> refrescarDesdeRemoto() async {
    try {
      await _syncService.sincronizarAhora();
      final remotos = await _remote.obtenerTodos();
      for (final cliente in remotos) {
        await _local.upsert(cliente);
      }

      // Borra localmente cualquier cliente que ya no exista en Firestore
      // (eliminado desde otro dispositivo).
      final idsRemotos = remotos.map((c) => c.id).toSet();
      final locales = await _local.obtenerTodos();
      for (final local in locales) {
        if (!idsRemotos.contains(local.id)) {
          await _local.eliminar(local.id);
        }
      }
    } catch (_) {
      // Sin conexión: la app sigue con la última caché local conocida.
    }
  }
}
