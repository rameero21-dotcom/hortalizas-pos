import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/stock.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/local/stock_local_datasource.dart';
import '../datasources/local/sync_queue_local_datasource.dart';
import '../datasources/remote/stock_remote_datasource.dart';
import '../models/stock_model.dart';

class StockRepositoryImpl implements StockRepository {
  final StockLocalDatasource _local;
  final SyncQueueLocalDatasource _syncQueue;
  final StockRemoteDatasource _remote;
  final _uuid = Uuid();

  StockRepositoryImpl(this._local, this._syncQueue, this._remote);

  @override
  Future<Stock?> obtenerPorProducto(String productoId) => _local.obtenerPorProducto(productoId);

  @override
  Future<List<Stock>> obtenerTodos() => _local.obtenerTodos();

  Future<void> _encolarStockYMovimiento(
      String productoId, double nuevaCantidad, MovimientoStockModel movimiento) async {
    await _syncQueue.encolar(
      entidad: AppConstants.colStock,
      entidadId: productoId,
      operacion: 'set',
      payload: {'productoId': productoId, 'cantidadDisponible': nuevaCantidad},
    );
    await _syncQueue.encolar(
      entidad: AppConstants.colMovimientosStock,
      entidadId: movimiento.id,
      operacion: 'set',
      payload: movimiento.toMap(),
    );
  }

  @override
  Future<void> descontarPorVenta(String productoId, double cantidad, String usuarioId) async {
    final actual = await _local.obtenerPorProducto(productoId);
    final cantidadActual = actual?.cantidadDisponible ?? 0;
    final nuevaCantidad = cantidadActual - cantidad;
    await _local.actualizarCantidad(productoId, nuevaCantidad);
    final movimiento = MovimientoStockModel(
      id: _uuid.v4(),
      productoId: productoId,
      tipo: TipoMovimientoStock.ventaDescuento,
      cantidad: -cantidad,
      fecha: DateTime.now(),
      usuarioId: usuarioId,
    );
    await _local.registrarMovimiento(movimiento);
    await _encolarStockYMovimiento(productoId, nuevaCantidad, movimiento);
  }

  @override
  Future<void> ingresarMercaderia(String productoId, double cantidad, String usuarioId, {String? nota}) async {
    final actual = await _local.obtenerPorProducto(productoId);
    final cantidadActual = actual?.cantidadDisponible ?? 0;
    final nuevaCantidad = cantidadActual + cantidad;
    await _local.actualizarCantidad(productoId, nuevaCantidad);
    final movimiento = MovimientoStockModel(
      id: _uuid.v4(),
      productoId: productoId,
      tipo: TipoMovimientoStock.ingreso,
      cantidad: cantidad,
      fecha: DateTime.now(),
      usuarioId: usuarioId,
      nota: nota,
    );
    await _local.registrarMovimiento(movimiento);
    await _encolarStockYMovimiento(productoId, nuevaCantidad, movimiento);
  }

  @override
  Future<void> ajusteManual(String productoId, double nuevaCantidad, String usuarioId, {String? nota}) async {
    final actual = await _local.obtenerPorProducto(productoId);
    final diferencia = nuevaCantidad - (actual?.cantidadDisponible ?? 0);
    await _local.actualizarCantidad(productoId, nuevaCantidad);
    final movimiento = MovimientoStockModel(
      id: _uuid.v4(),
      productoId: productoId,
      tipo: TipoMovimientoStock.ajusteManual,
      cantidad: diferencia,
      fecha: DateTime.now(),
      usuarioId: usuarioId,
      nota: nota,
    );
    await _local.registrarMovimiento(movimiento);
    await _encolarStockYMovimiento(productoId, nuevaCantidad, movimiento);
  }

  @override
  Future<void> registrarMerma(String productoId, double cantidad, String usuarioId, {String? nota}) async {
    final actual = await _local.obtenerPorProducto(productoId);
    final cantidadActual = actual?.cantidadDisponible ?? 0;
    final nuevaCantidad = cantidadActual - cantidad;
    await _local.actualizarCantidad(productoId, nuevaCantidad);
    final movimiento = MovimientoStockModel(
      id: _uuid.v4(),
      productoId: productoId,
      tipo: TipoMovimientoStock.merma,
      cantidad: -cantidad,
      fecha: DateTime.now(),
      usuarioId: usuarioId,
      nota: nota,
    );
    await _local.registrarMovimiento(movimiento);
    await _encolarStockYMovimiento(productoId, nuevaCantidad, movimiento);
  }

  @override
  Future<List<MovimientoStock>> obtenerHistorial(String productoId) {
    return _local.obtenerHistorial(productoId);
  }

  @override
  Stream<List<Stock>> observarStockBajo() {
    // TODO Fase 5: notificación push en tiempo real de stock bajo.
    // Por ahora StockScreen calcula el stock bajo localmente filtrando
    // `obtenerTodos()` con `Stock.stockBajo` (no necesita stream).
    throw UnimplementedError('observarStockBajo - Fase 5 (alertas push)');
  }

  @override
  Future<void> refrescarDesdeRemoto() async {
    try {
      final remotos = await _remote.obtenerTodos();
      for (final stock in remotos) {
        await _local.actualizarCantidad(stock.productoId, stock.cantidadDisponible);
      }
    } catch (_) {
      // Sin conexión: la app sigue con la última caché local conocida.
    }
  }
}
