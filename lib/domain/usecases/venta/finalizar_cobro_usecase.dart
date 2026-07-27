import '../../entities/venta.dart';
import '../../entities/cliente.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/cliente_repository.dart';

/// Caso de uso: la caja cobra una venta pendiente.
/// Descuenta stock automáticamente, marca la venta como cobrada con el
/// (o los) método(s) de pago, y si alguna parte se paga como "cuenta
/// corriente" (fiado), genera el cargo en la cuenta del cliente por esa
/// parte específica (no por el total, si el pago fue dividido).
class FinalizarCobroUseCase {
  final VentaRepository _ventaRepository;
  final StockRepository _stockRepository;
  final ClienteRepository _clienteRepository;

  FinalizarCobroUseCase(this._ventaRepository, this._stockRepository, this._clienteRepository);

  Future<Venta> call(
    Venta venta,
    String cajeroId,
    List<DetallePago> pagos, {
    String? clienteId,
  }) async {
    if (pagos.isEmpty) {
      throw ArgumentError('Hay que cargar al menos un método de pago');
    }
    final sumaPagos = pagos.fold<double>(0, (acc, p) => acc + p.monto);
    if ((sumaPagos - venta.total).abs() > 0.5) {
      throw ArgumentError(
          'La suma de los pagos (\$${sumaPagos.toStringAsFixed(0)}) no coincide con el total de la venta (\$${venta.total.toStringAsFixed(0)})');
    }

    final incluyeCuentaCorriente = pagos.any((p) => p.metodo == MetodoPago.cuentaCorriente);
    if (incluyeCuentaCorriente && (clienteId == null || clienteId.isEmpty)) {
      throw ArgumentError('Para cobrar a cuenta corriente hay que elegir un cliente');
    }

    for (final item in venta.detalle) {
      await _stockRepository.descontarPorVenta(item.productoId, item.cantidad, cajeroId);
    }

    // Si se pagó con un solo método, se guarda igual en `metodoPago` para
    // que las estadísticas/historial existentes (que agrupan por ese
    // campo) lo sigan viendo como antes. Si fueron varios, queda null ahí
    // y el detalle completo vive en `pagos`.
    final metodoPrincipal = pagos.length == 1 ? pagos.first.metodo : null;

    final ventaCobrada = venta.copyWith(
      estado: EstadoVenta.cobrada,
      metodoPago: metodoPrincipal,
      cajeroId: cajeroId,
      fechaCobro: DateTime.now(),
      clienteId: clienteId,
      pagos: pagos,
    );
    await _ventaRepository.finalizarCobro(ventaCobrada);

    if (incluyeCuentaCorriente) {
      final montoCuentaCorriente = pagos
          .where((p) => p.metodo == MetodoPago.cuentaCorriente)
          .fold<double>(0, (acc, p) => acc + p.monto);
      await _clienteRepository.registrarMovimientoCuenta(
        clienteId: clienteId!,
        tipo: TipoMovimientoCuenta.cargo,
        monto: montoCuentaCorriente,
        detalle: 'Venta #${venta.numero}',
        usuarioId: cajeroId,
      );
    }

    return ventaCobrada;
  }
}
