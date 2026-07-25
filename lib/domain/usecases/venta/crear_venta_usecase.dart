import '../../entities/venta.dart';
import '../../repositories/venta_repository.dart';

/// Caso de uso: el vendedor finaliza una venta nueva.
/// Guarda localmente (SQLite) con numeración automática y encola la
/// sincronización a Firestore (Fase 2). Devuelve la venta ya numerada
/// para poder generar el QR de respaldo.
class CrearVentaUseCase {
  final VentaRepository _ventaRepository;
  CrearVentaUseCase(this._ventaRepository);

  Future<Venta> call(Venta venta) async {
    if (venta.detalle.isEmpty) {
      throw ArgumentError('La venta debe tener al menos un producto');
    }
    return _ventaRepository.crearVenta(venta);
  }
}
