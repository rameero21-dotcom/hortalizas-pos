import '../../entities/venta.dart';
import '../../entities/detalle_venta.dart';
import '../../entities/cliente.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/cliente_repository.dart';

/// Caso de uso: editar el detalle de una venta ya creada (por ejemplo,
/// el cliente decide agregar un producto más, o sacar uno), y/o su
/// forma de pago (ej: se cobró como "Efectivo" por error y en realidad
/// era "Cuenta corriente").
///
/// - Si la venta todavía está PENDIENTE (el vendedor la mandó pero caja
///   todavía no la cobró): simplemente se actualiza el detalle y el
///   total, no hay stock ni cuenta corriente que reconciliar todavía
///   (eso pasa recién al cobrar).
/// - Si la venta ya está COBRADA: hay que reconciliar dos cosas:
///   - El STOCK: por cada producto, si ahora se pide más cantidad que
///     antes, se descuenta la diferencia; si se pide menos (o se sacó
///     el producto), se devuelve la diferencia.
///   - La CUENTA CORRIENTE: si la forma de pago sigue siendo fiado, la
///     deuda del cliente se ajusta por la diferencia entre el total
///     viejo y el nuevo. Si CAMBIA de/hacia fiado (o cambia el cliente
///     fiado), se cancela lo que había cargado la venta original y se
///     carga de nuevo según corresponda — nunca se mezcla.
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

  Future<void> call(
    Venta ventaOriginal,
    List<DetalleVenta> nuevoDetalle,
    String usuarioId, {
    MetodoPago? nuevoMetodoPago,
    String? nuevoClienteId,
  }) async {
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

    final metodoActual =
        ventaOriginal.pagos.isNotEmpty ? ventaOriginal.pagos.first.metodo : ventaOriginal.metodoPago;
    final metodoFinal = nuevoMetodoPago ?? metodoActual;
    final clienteIdFinal = nuevoClienteId ?? ventaOriginal.clienteId;

    if (metodoFinal == MetodoPago.cuentaCorriente && clienteIdFinal == null) {
      throw ArgumentError('Para cobrar a cuenta corriente hace falta elegir un cliente.');
    }

    final nuevoTotal = nuevoDetalle.fold<double>(0, (acc, d) => acc + d.precioTotal);

    if (ventaOriginal.estado == EstadoVenta.cobrada) {
      await _reconciliarStock(ventaOriginal.detalle, nuevoDetalle, usuarioId, ventaOriginal.numero);
      await _reconciliarCuentaCorriente(
        ventaOriginal,
        nuevoTotal,
        metodoActual,
        metodoFinal,
        clienteIdFinal,
        usuarioId,
      );
    }

    final ventaActualizada = ventaOriginal.copyWith(
      detalle: nuevoDetalle,
      total: nuevoTotal,
      metodoPago: metodoFinal,
      clienteId: clienteIdFinal,
      pagos: ventaOriginal.pagos.isNotEmpty ? [DetallePago(metodo: metodoFinal!, monto: nuevoTotal)] : null,
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

  /// Reconcilia el impacto en cuenta corriente, contemplando los 4 casos
  /// posibles entre la forma de pago/cliente VIEJOS y los NUEVOS:
  /// - No era fiado y sigue sin serlo: no hay nada que tocar.
  /// - Era fiado y deja de serlo: se cancela (se registra un pago por) el
  ///   total viejo completo en la cuenta del cliente original.
  /// - No era fiado y pasa a serlo: se carga el total nuevo completo en
  ///   la cuenta del cliente elegido.
  /// - Seguía fiado con el MISMO cliente: se ajusta solo por la
  ///   diferencia entre el total viejo y el nuevo (como antes).
  /// - Seguía fiado pero se reasignó a OTRO cliente: se cancela el total
  ///   viejo en el cliente original y se carga el total nuevo en el
  ///   nuevo, nunca se mezclan las dos cuentas.
  Future<void> _reconciliarCuentaCorriente(
    Venta ventaOriginal,
    double nuevoTotal,
    MetodoPago? metodoAnterior,
    MetodoPago? metodoFinal,
    String? clienteIdFinal,
    String usuarioId,
  ) async {
    final eraFiado = metodoAnterior == MetodoPago.cuentaCorriente && ventaOriginal.clienteId != null;
    final esFiadoAhora = metodoFinal == MetodoPago.cuentaCorriente && clienteIdFinal != null;

    if (!eraFiado && !esFiadoAhora) return;

    if (eraFiado && !esFiadoAhora) {
      await _clienteRepository.registrarMovimientoCuenta(
        clienteId: ventaOriginal.clienteId!,
        tipo: TipoMovimientoCuenta.pago,
        monto: ventaOriginal.total,
        detalle: 'Edición de venta #${ventaOriginal.numero} (cambio de forma de pago)',
        usuarioId: usuarioId,
      );
      return;
    }

    if (!eraFiado && esFiadoAhora) {
      await _clienteRepository.registrarMovimientoCuenta(
        clienteId: clienteIdFinal,
        tipo: TipoMovimientoCuenta.cargo,
        monto: nuevoTotal,
        detalle: 'Edición de venta #${ventaOriginal.numero} (cambio de forma de pago)',
        usuarioId: usuarioId,
      );
      return;
    }

    // eraFiado && esFiadoAhora:
    if (clienteIdFinal != ventaOriginal.clienteId) {
      await _clienteRepository.registrarMovimientoCuenta(
        clienteId: ventaOriginal.clienteId!,
        tipo: TipoMovimientoCuenta.pago,
        monto: ventaOriginal.total,
        detalle: 'Edición de venta #${ventaOriginal.numero} (cambio de cliente)',
        usuarioId: usuarioId,
      );
      await _clienteRepository.registrarMovimientoCuenta(
        clienteId: clienteIdFinal!,
        tipo: TipoMovimientoCuenta.cargo,
        monto: nuevoTotal,
        detalle: 'Edición de venta #${ventaOriginal.numero} (cambio de cliente)',
        usuarioId: usuarioId,
      );
      return;
    }

    final diferencia = nuevoTotal - ventaOriginal.total;
    if (diferencia == 0) return;
    await _clienteRepository.registrarMovimientoCuenta(
      clienteId: clienteIdFinal!,
      tipo: diferencia > 0 ? TipoMovimientoCuenta.cargo : TipoMovimientoCuenta.pago,
      monto: diferencia.abs(),
      detalle: 'Edición de venta #${ventaOriginal.numero}',
      usuarioId: usuarioId,
    );
  }
}
