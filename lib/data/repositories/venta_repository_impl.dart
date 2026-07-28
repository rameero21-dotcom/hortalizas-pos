import '../../core/constants/app_constants.dart';
import '../../core/services/qr_service.dart';
import '../../core/services/sync_service.dart';
import '../../domain/entities/detalle_venta.dart';
import '../../domain/entities/venta.dart';
import '../../domain/repositories/venta_repository.dart';
import '../datasources/local/sync_queue_local_datasource.dart';
import '../datasources/local/venta_local_datasource.dart';
import '../datasources/remote/venta_remote_datasource.dart';
import '../models/venta_model.dart';

class VentaRepositoryImpl implements VentaRepository {
  final VentaLocalDatasource _local;
  final SyncQueueLocalDatasource _syncQueue;
  final QrService _qrService;
  final VentaRemoteDatasource _remote;
  final SyncService _syncService;

  VentaRepositoryImpl(this._local, this._syncQueue, this._qrService, this._remote, this._syncService);

  @override
  Future<Venta> crearVenta(Venta venta) async {
    final model = VentaModel(
      id: venta.id,
      numero: venta.numero,
      fecha: venta.fecha,
      vendedorId: venta.vendedorId,
      detalle: venta.detalle,
      total: venta.total,
      nombreCliente: venta.nombreCliente,
    );
    final ventaCreada = await _local.crear(model); // asigna el número correlativo real

    final modelConNumero = VentaModel(
      id: ventaCreada.id,
      numero: ventaCreada.numero,
      fecha: ventaCreada.fecha,
      vendedorId: ventaCreada.vendedorId,
      detalle: ventaCreada.detalle,
      total: ventaCreada.total,
      estado: ventaCreada.estado,
      nombreCliente: ventaCreada.nombreCliente,
    );

    await _syncQueue.encolar(
      entidad: AppConstants.colVentas,
      entidadId: modelConNumero.id,
      operacion: 'set',
      payload: modelConNumero.toRemoteMap(), // incluye el detalle embebido
    );

    // Sube la venta a Firestore YA, para que aparezca en caja al toque
    // en vez de esperar al próximo ciclo automático de sincronización.
    await _syncService.sincronizarAhora();

    return ventaCreada;
  }

  @override
  Future<Venta?> obtenerPorId(String id) => _local.obtenerPorId(id);

  @override
  Future<List<Venta>> obtenerPendientes() => _local.obtenerPendientes();

  @override
  Future<List<Venta>> obtenerPorRangoFecha(DateTime desde, DateTime hasta) =>
      _local.obtenerPorRangoFecha(desde, hasta);

  @override
  Future<List<Venta>> obtenerPorRangoFechaGlobal(DateTime desde, DateTime hasta) =>
      _remote.obtenerPorRangoFecha(desde, hasta);

  @override
  Future<List<Venta>> obtenerPorCliente(String clienteId) => _remote.obtenerPorCliente(clienteId);

  @override
  Future<void> eliminarVenta(String id) async {
    await _local.eliminar(id);
    await _syncQueue.encolar(
      entidad: AppConstants.colVentas,
      entidadId: id,
      operacion: 'delete',
      payload: const {},
    );
    // Se sube el borrado a Firestore YA (no esperar al próximo ciclo de
    // sincronización), para que desaparezca de inmediato de cualquier
    // otra pantalla que la esté mirando (historial, cuenta corriente,
    // ventas pendientes de otro dispositivo).
    await _syncService.sincronizarAhora();
  }

  @override
  Future<Venta?> obtenerEstadoActualDesdeRemoto(String id) async {
    try {
      return await _remote.obtenerPorIdRemoto(id);
    } catch (_) {
      return null; // sin conexión: el llamador decide cómo seguir
    }
  }

  @override
  Future<void> finalizarCobro(Venta venta) async {
    final model = VentaModel(
      id: venta.id,
      numero: venta.numero,
      fecha: venta.fecha,
      vendedorId: venta.vendedorId,
      detalle: venta.detalle,
      total: venta.total,
      estado: venta.estado,
      metodoPago: venta.metodoPago,
      cajeroId: venta.cajeroId,
      fechaCobro: venta.fechaCobro,
      clienteId: venta.clienteId,
      nombreCliente: venta.nombreCliente,
      pagos: venta.pagos,
    );

    // Si la venta nunca existió en el SQLite de este dispositivo (caso
    // típico: se reconstruyó desde el QR porque el celular del vendedor
    // no llegó a sincronizarla), hay que guardarla completa. Si ya
    // existía (flujo normal, sincronizada por Firestore), alcanza con
    // actualizar su estado.
    final existente = await _local.obtenerPorId(venta.id);
    if (existente == null) {
      await _local.guardarCompleta(model);
    } else {
      await _local.actualizarEstadoCobro(model);
    }

    await _syncQueue.encolar(
      entidad: AppConstants.colVentas,
      entidadId: model.id,
      operacion: 'set',
      payload: model.toRemoteMap(),
    );
    await _syncService.sincronizarAhora();
  }

  @override
  Stream<List<Venta>> observarPendientes() {
    // La UI de caja (CajaHomeScreen) escucha directo el stream de
    // VentaRemoteDatasource; este método queda para cuando se agregue
    // fallback 100% local (sin conexión) más adelante.
    throw UnimplementedError('observarPendientes - usar VentaRemoteDatasource desde la UI');
  }

  @override
  Future<Venta> reconstruirDesdeQr(String qrPayload) async {
    // El QR es solo un respaldo: si falla la sincronización por red, la
    // caja puede reconstruir la venta completa leyendo únicamente el QR,
    // sin necesitar conexión ni consultar Firestore/SQLite.
    final data = _qrService.decodificarPayload(qrPayload);

    final detalle = (data['productos'] as List<dynamic>)
        .map((p) => DetalleVenta(
              productoId: p['productoId'] as String,
              nombreProducto: p['nombre'] as String,
              cantidad: (p['cantidad'] as num).toDouble(),
              precioTotal: (p['precioTotal'] as num).toDouble(),
            ))
        .toList();

    return Venta(
      id: data['id'] as String,
      numero: data['numero'] as int,
      fecha: DateTime.parse(data['fecha'] as String),
      vendedorId: data['vendedorId'] as String,
      detalle: detalle,
      total: (data['total'] as num).toDouble(),
      nombreCliente: data['nombreCliente'] as String?,
    );
  }
}
