import '../../entities/venta.dart';
import '../../entities/cliente.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/cliente_repository.dart';

/// Caso de uso: la caja cobra una venta pendiente.
/// Descuenta stock automáticamente, marca la venta como cobrada con su
/// método de pago, y si se paga como "cuenta corriente" (fiado), genera
/// el cargo en la cuenta del cliente sin pasos manuales adicionales.
class FinalizarCobroUseCase {
  final VentaRepository _ventaRepository;
  final StockRepository _stockRepository;
  final ClienteRepository _clienteRepository;

  FinalizarCobroUseCase(this._ventaRepository, this._stockRepository, this._clienteRepository);

  Future<Venta> call(
    Venta venta,
    String cajeroId,
    MetodoPago metodoPago, {
    String? clienteId,
  }) async {
    if (metodoPago == MetodoPago.cuentaCorriente && (clienteId == null || clienteId.isEmpty)) {
      throw ArgumentError('Para cobrar a cuenta corriente hay que elegir un cliente');
    }

    for (final item in venta.detalle) {
      await _stockRepository.descontarPorVenta(item.productoId, item.cantidad, cajeroId);
    }

    final ventaCobrada = venta.copyWith(
      estado: EstadoVenta.cobrada,
      metodoPago: metodoPago,
      cajeroId: cajeroId,
      fechaCobro: DateTime.now(),
      clienteId: clienteId,
    );
    await _ventaRepository.finalizarCobro(ventaCobrada);

    if (metodoPago == MetodoPago.cuentaCorriente) {
      await _clienteRepository.registrarMovimientoCuenta(
        clienteId: clienteId!,
        tipo: TipoMovimientoCuenta.cargo,
        monto: venta.total,
        detalle: 'Venta #${venta.numero}',
        usuarioId: cajeroId,
      );
    }

    return ventaCobrada;
  }
}
