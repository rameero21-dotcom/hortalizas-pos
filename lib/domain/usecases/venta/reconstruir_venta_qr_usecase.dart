import '../../entities/venta.dart';
import '../../repositories/venta_repository.dart';

/// Caso de uso: reconstruir una venta completa a partir del QR
/// escaneado en caja, cuando falla la sincronización por red.
class ReconstruirVentaQrUseCase {
  final VentaRepository _ventaRepository;
  ReconstruirVentaQrUseCase(this._ventaRepository);

  Future<Venta> call(String qrPayload) {
    return _ventaRepository.reconstruirDesdeQr(qrPayload);
  }
}
