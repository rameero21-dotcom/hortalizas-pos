import '../../entities/producto.dart';
import '../../repositories/producto_repository.dart';

/// Agrupa las operaciones de administración de productos (CRUD + activar/desactivar).
class GestionarProductosUseCase {
  final ProductoRepository _productoRepository;
  GestionarProductosUseCase(this._productoRepository);

  Future<void> crear(Producto producto) => _productoRepository.crear(producto);
  Future<void> actualizar(Producto producto) => _productoRepository.actualizar(producto);
  Future<void> eliminar(String id) => _productoRepository.eliminar(id);

  Future<void> activarDesactivar(Producto producto, bool activo) {
    return _productoRepository.actualizar(producto.copyWith(activo: activo));
  }
}
