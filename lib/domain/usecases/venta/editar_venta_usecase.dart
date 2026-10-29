import '../../entities/venta.dart';
import '../../entities/detalle_venta.dart';
import '../../entities/cliente.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/cliente_repository.dart';

/// Caso de uso: editar el detalle de una venta ya COBRADA (por ejemplo,
/// el cliente decide agregar un producto más, o sacar uno), y/o su
/// forma de pago (ej: se cobró como "Efectivo" por error y en realidad
/// era "Cuenta corriente", o había que dividirla entre dos métodos).
///
/// - El STOCK se reconcilia por la diferencia: por cada producto, si
///   ahora se pide más cantidad que antes, se descuenta la diferencia;
///   si se pide menos (o se sacó el producto), se devuelve.
/// - La CUENTA CORRIENTE se reconcilia por el MONTO fiado (no por el
///   total): se compara cuánto de la venta estaba cargado como "cuenta
///   corriente" antes contra cuánto queda ahora (puede ser una parte
///   de un pago dividido) y se ajusta la diferencia en la cuenta del
///   cliente correspondiente — si además se reasignó a otro cliente,
///   se cancela lo viejo en el cliente original y se carga lo nuevo en
///   el otro, sin mezclar las dos cuentas.
///
/// Para una venta todavía PENDIENTE (no cobrada), este caso de uso no
/// se usa: ver FinalizarCobroUseCase, que la cobra directamente con la
/// forma de pago elegida.
class EditarVentaUseCase {
  final VentaRepository _ventaRepository;
  final StockRepository _stockRepository;
  final ClienteRepository _clienteRepository;

  EditarVentaUseCase(this._ventaRepository, this._stockRepository, this._clienteRepository);

  Future<void> call(
    Venta ventaOriginal,
    List<DetalleVenta> nuevoDetalle,
    List<DetallePago> nuevosPagos,
    String usuarioId, {
    String? nuevoClienteId,
  }) async {
    // Se confirma contra el estado REAL del servidor antes de tocar nada
    // — el objeto que llega acá puede venir de una pantalla que se abrió
    // hace un rato (por ejemplo, Historial), y mientras tanto otro admin
    // pudo haber anulado o editado esta misma venta. Si no hay conexión,
    // se sigue con lo que ya se tenía (offline-first), igual que al cobrar.
    final estadoReal = await _ventaRepository.obtenerEstadoActualDesdeRemoto(ventaOriginal.id);
    if (estadoReal != null) ventaOriginal = estadoReal;

    if (ventaOriginal.estado != EstadoVenta.cobrada) {
      throw ArgumentError(
          'Esta venta no está cobrada todavía: usá la pantalla de cobro en Caja, no la edición.');
    }
    if (nuevoDetalle.isEmpty) {
      throw ArgumentError('La venta tiene que tener al menos un producto.');
    }
    if (nuevosPagos.isEmpty) {
      throw ArgumentError('Hay que cargar al menos un método de pago.');
    }

    final nuevoTotal = nuevoDetalle.fold<double>(0, (acc, d) => acc + d.precioTotal);
    final sumaPagos = nuevosPagos.fold<double>(0, (acc, p) => acc + p.monto);
    if ((sumaPagos - nuevoTotal).abs() > 0.5) {
      throw ArgumentError(
          'La suma de los pagos (\$${sumaPagos.toStringAsFixed(0)}) no coincide con el total de la venta (\$${nuevoTotal.toStringAsFixed(0)}).');
    }

    final incluyeFiado = nuevosPagos.any((p) => p.metodo == MetodoPago.cuentaCorriente);
    final clienteIdFinal = nuevoClienteId ?? ventaOriginal.clienteId;
    if (incluyeFiado && clienteIdFinal == null) {
      throw ArgumentError('Para cobrar una parte a cuenta corriente hace falta elegir un cliente.');
    }

    await _reconciliarStock(ventaOriginal.detalle, nuevoDetalle, usuarioId, ventaOriginal.numero);
    await _reconciliarCuentaCorriente(ventaOriginal, nuevosPagos, nuevoClienteId, usuarioId);

    final metodoPrincipal = nuevosPagos.length == 1 ? nuevosPagos.first.metodo : null;
    final ventaActualizada = ventaOriginal.copyWith(
      detalle: nuevoDetalle,
      total: nuevoTotal,
      metodoPago: metodoPrincipal,
      clienteId: clienteIdFinal,
      pagos: nuevosPagos,
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

  /// Reconcilia el impacto en cuenta corriente comparando el MONTO
  /// fiado de antes contra el de ahora (no un total completo ni un
  /// booleano "era/es fiado"): una venta puede tener solo una PARTE
  /// pagada a cuenta corriente, y esa parte puede cambiar de monto, de
  /// cliente, aparecer donde antes no había, o desaparecer del todo.
  Future<void> _reconciliarCuentaCorriente(
    Venta ventaOriginal,
    List<DetallePago> nuevosPagos,
    String? nuevoClienteId,
    String usuarioId,
  ) async {
    final montoFiadoAnterior = ventaOriginal.pagos.isNotEmpty
        ? ventaOriginal.pagos
            .where((p) => p.metodo == MetodoPago.cuentaCorriente)
            .fold<double>(0, (acc, p) => acc + p.monto)
        : (ventaOriginal.metodoPago == MetodoPago.cuentaCorriente ? ventaOriginal.total : 0.0);
    final montoFiadoNuevo = nuevosPagos
        .where((p) => p.metodo == MetodoPago.cuentaCorriente)
        .fold<double>(0, (acc, p) => acc + p.monto);

    if (montoFiadoAnterior == 0 && montoFiadoNuevo == 0) return;

    final clienteAnterior = ventaOriginal.clienteId;
    final clienteNuevo = montoFiadoNuevo > 0 ? (nuevoClienteId ?? ventaOriginal.clienteId) : null;

    if (clienteAnterior != null && montoFiadoAnterior > 0 && clienteAnterior != clienteNuevo) {
      // Se reasignó a otro cliente (o se sacó el fiado del todo): se
      // cancela lo que tenía cargado el cliente original...
      await _clienteRepository.registrarMovimientoCuenta(
        clienteId: clienteAnterior,
        tipo: TipoMovimientoCuenta.pago,
        monto: montoFiadoAnterior,
        detalle: 'Edición de venta #${ventaOriginal.numero} (cambio de forma de pago)',
        usuarioId: usuarioId,
      );
      // ...y si sigue habiendo una parte fiada, se carga en el nuevo.
      if (clienteNuevo != null && montoFiadoNuevo > 0) {
        await _clienteRepository.registrarMovimientoCuenta(
          clienteId: clienteNuevo,
          tipo: TipoMovimientoCuenta.cargo,
          monto: montoFiadoNuevo,
          detalle: 'Edición de venta #${ventaOriginal.numero} (cambio de forma de pago)',
          usuarioId: usuarioId,
        );
      }
      return;
    }

    // Mismo cliente (o no había cliente fiado antes y ahora sí): se
    // ajusta solo por la diferencia del monto fiado.
    final diferencia = montoFiadoNuevo - montoFiadoAnterior;
    if (diferencia == 0) return;
    final clienteId = clienteNuevo ?? clienteAnterior;
    if (clienteId == null) return;
    await _clienteRepository.registrarMovimientoCuenta(
      clienteId: clienteId,
      tipo: diferencia > 0 ? TipoMovimientoCuenta.cargo : TipoMovimientoCuenta.pago,
      monto: diferencia.abs(),
      detalle: 'Edición de venta #${ventaOriginal.numero}',
      usuarioId: usuarioId,
    );
  }
}
