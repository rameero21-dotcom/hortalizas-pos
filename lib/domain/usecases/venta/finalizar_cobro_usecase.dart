import '../../entities/venta.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/stock_repository.dart';

/// Caso de uso: la caja cobra una venta pendiente.
/// Descuenta stock automáticamente y marca la venta como cobrada con
/// su método de pago.
class FinalizarCobroUseCase {
  final VentaRepository _ventaRepository;
  final StockRepository _stockRepository;

  FinalizarCobroUseCase(this._ventaRepository, this._stockRepository);

  Future<Venta> call(Venta venta, String cajeroId, MetodoPago metodoPago) async {
    for (final item in venta.detalle) {
      await _stockRepository.descontarPorVenta(item.productoId, item.cantidad, cajeroId);
    }
    final ventaCobrada = venta.copyWith(
      estado: EstadoVenta.cobrada,
      metodoPago: metodoPago,
      cajeroId: cajeroId,
      fechaCobro: DateTime.now(),
    );
    await _ventaRepository.finalizarCobro(ventaCobrada);
    return ventaCobrada;
  }
}
