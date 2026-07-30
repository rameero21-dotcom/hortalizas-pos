import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/sync_service.dart';
import '../../domain/entities/proveedor.dart';
import '../../domain/repositories/proveedor_repository.dart';
import '../datasources/local/proveedor_local_datasource.dart';
import '../datasources/local/sync_queue_local_datasource.dart';
import '../datasources/remote/proveedor_remote_datasource.dart';
import '../models/proveedor_model.dart';

class ProveedorRepositoryImpl implements ProveedorRepository {
  final ProveedorLocalDatasource _local;
  final SyncQueueLocalDatasource _syncQueue;
  final ProveedorRemoteDatasource _remote;
  final SyncService _syncService;
  final _uuid = const Uuid();

  ProveedorRepositoryImpl(this._local, this._syncQueue, this._remote, this._syncService);

  @override
  Future<List<Proveedor>> obtenerTodos() => _local.obtenerTodos();

  @override
  Future<void> crear(Proveedor proveedor) async {
    final model = ProveedorModel.fromEntity(proveedor);
    await _local.upsert(model);
    await _syncQueue.encolar(
      entidad: AppConstants.colProveedores,
      entidadId: model.id,
      operacion: 'set',
      payload: model.toMap(),
    );
    await _syncService.sincronizarAhora();
  }

  @override
  Future<void> actualizar(Proveedor proveedor) => crear(proveedor);

  @override
  Future<void> eliminar(String id) async {
    await _local.eliminar(id);
    await _syncQueue.encolar(
      entidad: AppConstants.colProveedores,
      entidadId: id,
      operacion: 'delete',
      payload: const {},
    );
    await _syncService.sincronizarAhora();
  }

  @override
  Future<List<PedidoProveedor>> obtenerPedidos(String proveedorId) => _local.obtenerPedidos(proveedorId);

  @override
  Future<List<PedidoProveedor>> obtenerTodosLosPedidosGlobal() => _remote.obtenerTodosLosPedidos();

  @override
  Future<void> registrarPedido(PedidoProveedor pedido) async {
    final model = PedidoProveedorModel(
      id: pedido.id.isEmpty ? _uuid.v4() : pedido.id,
      proveedorId: pedido.proveedorId,
      productoId: pedido.productoId,
      productoNombre: pedido.productoNombre,
      cantidad: pedido.cantidad,
      metodoPago: pedido.metodoPago,
      monto: pedido.monto,
      fecha: pedido.fecha,
      usuarioId: pedido.usuarioId,
      nota: pedido.nota,
    );
    await _local.registrarPedido(model);
    await _syncQueue.encolar(
      entidad: AppConstants.colPedidosProveedor,
      entidadId: model.id,
      operacion: 'set',
      payload: model.toMap(),
    );

    // Pedir mercadería SUMA a lo que le debemos al proveedor.
    final proveedores = await _local.obtenerTodos();
    Proveedor? proveedor;
    for (final p in proveedores) {
      if (p.id == pedido.proveedorId) {
        proveedor = p;
        break;
      }
    }
    final saldoActual = proveedor?.saldoCuentaCorriente ?? 0;
    final nuevoSaldo = saldoActual + pedido.monto;
    await _local.actualizarSaldo(pedido.proveedorId, nuevoSaldo);
    await _syncQueue.encolar(
      entidad: AppConstants.colProveedores,
      entidadId: pedido.proveedorId,
      operacion: 'set',
      payload: {'id': pedido.proveedorId, 'saldoCuentaCorriente': nuevoSaldo},
    );

    await _syncService.sincronizarAhora();
  }

  @override
  Future<void> eliminarPedido(String id) async {
    await _local.eliminarPedido(id);
    await _syncQueue.encolar(
      entidad: AppConstants.colPedidosProveedor,
      entidadId: id,
      operacion: 'delete',
      payload: const {},
    );
    await _syncService.sincronizarAhora();
  }

  @override
  Future<void> registrarPago(PagoProveedor pago) async {
    final model = PagoProveedorModel(
      id: pago.id.isEmpty ? _uuid.v4() : pago.id,
      proveedorId: pago.proveedorId,
      monto: pago.monto,
      metodoPago: pago.metodoPago,
      fecha: pago.fecha,
      usuarioId: pago.usuarioId,
      nota: pago.nota,
    );
    await _local.registrarPago(model);
    await _syncQueue.encolar(
      entidad: AppConstants.colPagosProveedor,
      entidadId: model.id,
      operacion: 'set',
      payload: model.toMap(),
    );

    // Pagarle al proveedor RESTA de lo que le debemos.
    final proveedores = await _local.obtenerTodos();
    Proveedor? proveedor;
    for (final p in proveedores) {
      if (p.id == pago.proveedorId) {
        proveedor = p;
        break;
      }
    }
    final saldoActual = proveedor?.saldoCuentaCorriente ?? 0;
    final nuevoSaldo = saldoActual - pago.monto;
    await _local.actualizarSaldo(pago.proveedorId, nuevoSaldo);
    await _syncQueue.encolar(
      entidad: AppConstants.colProveedores,
      entidadId: pago.proveedorId,
      operacion: 'set',
      payload: {'id': pago.proveedorId, 'saldoCuentaCorriente': nuevoSaldo},
    );

    await _syncService.sincronizarAhora();
  }

  @override
  Future<void> eliminarPago(String id) async {
    await _local.eliminarPago(id);
    await _syncQueue.encolar(
      entidad: AppConstants.colPagosProveedor,
      entidadId: id,
      operacion: 'delete',
      payload: const {},
    );
    await _syncService.sincronizarAhora();
  }

  @override
  Future<List<PagoProveedor>> obtenerPagos(String proveedorId) => _local.obtenerPagos(proveedorId);

  @override
  Future<List<PagoProveedor>> obtenerTodosLosPagosGlobal() => _remote.obtenerTodosLosPagos();

  @override
  Future<void> refrescarDesdeRemoto() async {
    try {
      await _syncService.sincronizarAhora();
      final remotos = await _remote.obtenerTodos();
      for (final proveedor in remotos) {
        await _local.upsert(proveedor);
      }

      // Borra localmente cualquier proveedor que ya no exista en
      // Firestore (eliminado desde otro dispositivo).
      final idsRemotos = remotos.map((p) => p.id).toSet();
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
