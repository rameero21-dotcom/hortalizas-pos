import '../../entities/venta.dart';
import '../../entities/detalle_venta.dart';
import '../../entities/cliente.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/cliente_repository.dart';

/// Caso de uso: editar el detalle de una venta ya creada (por ejemplo,
/// el cliente decide agregar un producto más, o sacar uno).
///
/// - Si la venta todavía está PENDIENTE (el vendedor la mandó pero caja
///   todavía no la cobró): simplemente se actualiza el detalle y el
///   total, no hay stock ni cuenta corriente que reconciliar todavía
///   (eso pasa recién al cobrar).
/// - Si la venta ya está COBRADA: hay que reconciliar dos cosas:
///   - El STOCK: por cada producto, si ahora se pide más cantidad que
///     antes, se descuenta la diferencia; si se pide menos (o se sacó
///     el producto), se devuelve la diferencia.
///   - La CUENTA CORRIENTE: si se había pagado fiado, la deuda del
///     cliente se ajusta por la diferencia entre el total viejo y el
///     nuevo (no se vuelve a cargar el total entero).
///
/// No soporta editar una venta con el pago DIVIDIDO entre varios
/// métodos (ej: parte efectivo + parte fiado) — para ese caso hay que
/// anular y volver a cargar, así no se corre el riesgo de repartir mal
/// la diferencia entre los métodos.
class EditarVentaUseCase {
  final VentaRepository _ventaRepository;
  final StockRepository _stockRepository;
  final ClienteRepository _clienteRepository;

  EditarVentaUseCase(this._ventaRepository, this._stockRepository, this._clienteRepository);

  Future<void> call(Venta ventaOriginal, List<DetalleVenta> nuevoDetalle, String usuarioId) async {
    // Se confirma contra el estado REAL del servidor antes de tocar nada
    // — el objeto que llega acá puede venir de una pantalla que se abrió
    // hace un rato (por ejemplo, Historial), y mientras tanto otro admin
    // pudo haber anulado o editado esta misma venta. Si no hay conexión,
    // se sigue con lo que ya se tenía (offline-first), igual que al cobrar.
    final estadoReal = await _ventaRepository.obtenerEstadoActualDesdeRemoto(ventaOriginal.id);
    if (estadoReal != null) ventaOriginal = estadoReal;

    if (ventaOriginal.estado == EstadoVenta.cancelada) {
      throw ArgumentError('No se puede editar una venta anulada.');
    }
    if (ventaOriginal.pagos.length > 1) {
      throw ArgumentError(
          'Esta venta se cobró con el pago dividido entre varios métodos: no se puede editar directamente. Anulala y cargala de nuevo.');
    }
    if (nuevoDetalle.isEmpty) {
      throw ArgumentError('La venta tiene que tener al menos un producto.');
    }

    final nuevoTotal = nuevoDetalle.fold<double>(0, (acc, d) => acc + d.precioTotal);

    if (ventaOriginal.estado == EstadoVenta.cobrada) {
      await _reconciliarStock(ventaOriginal.detalle, nuevoDetalle, usuarioId, ventaOriginal.numero);
      await _reconciliarCuentaCorriente(ventaOriginal, nuevoTotal, usuarioId);
    }

    final metodoUnico =
        ventaOriginal.pagos.isNotEmpty ? ventaOriginal.pagos.first.metodo : ventaOriginal.metodoPago;
    final ventaActualizada = ventaOriginal.copyWith(
      detalle: nuevoDetalle,
      total: nuevoTotal,
      pagos: ventaOriginal.pagos.isNotEmpty ? [DetallePago(metodo: metodoUnico!, monto: nuevoTotal)] : null,
    );
    await _ventaRepository.finalizarCobro(ventaActualizada);
  }

  Future<void> _reconciliarStock(
    List<DetalleVenta> viejo,
    List<DetalleVenta> nuevo,
    String usuarioId,
    int numeroVenta,
  ) async {
    final cantidadViejaPorProducto = <String, double>{};
    for (final d in viejo) {
      cantidadViejaPorProducto[d.productoId] = (cantidadViejaPorProducto[d.productoId] ?? 0) + d.cantidad;
    }
    final cantidadNuevaPorProducto = <String, double>{};
    for (final d in nuevo) {
      cantidadNuevaPorProducto[d.productoId] = (cantidadNuevaPorProducto[d.productoId] ?? 0) + d.cantidad;
    }

    final todosLosProductos = {...cantidadViejaPorProducto.keys, ...cantidadNuevaPorProducto.keys};
    for (final productoId in todosLosProductos) {
      final antes = cantidadViejaPorProducto[productoId] ?? 0;
      final despues = cantidadNuevaPorProducto[productoId] ?? 0;
      final diferencia = despues - antes;
      if (diferencia > 0) {
        // Se pidió MÁS que antes: descontar la diferencia.
        await _stockRepository.descontarPorVenta(productoId, diferencia, usuarioId);
      } else if (diferencia < 0) {
        // Se pidió MENOS que antes (o se sacó el producto): devolver.
        await _stockRepository.ingresarMercaderia(
          productoId,
          -diferencia,
          usuarioId,
          nota: 'Edición de venta #$numeroVenta',
        );
      }
    }
  }

  Future<void> _reconciliarCuentaCorriente(Venta ventaOriginal, double nuevoTotal, String usuarioId) async {
    final eraFiado = ventaOriginal.pagos.isNotEmpty
        ? ventaOriginal.pagos.first.metodo == MetodoPago.cuentaCorriente
        : ventaOriginal.metodoPago == MetodoPago.cuentaCorriente;
    if (!eraFiado || ventaOriginal.clienteId == null) return;

    final diferencia = nuevoTotal - ventaOriginal.total;
    if (diferencia == 0) return;

    // Si el total subió, se le carga la diferencia como un cargo nuevo
    // (más deuda); si bajó, se le registra como un pago (menos deuda).
    await _clienteRepository.registrarMovimientoCuenta(
      clienteId: ventaOriginal.clienteId!,
      tipo: diferencia > 0 ? TipoMovimientoCuenta.cargo : TipoMovimientoCuenta.pago,
      monto: diferencia.abs(),
      detalle: 'Edición de venta #${ventaOriginal.numero}',
      usuarioId: usuarioId,
    );
  }
}
