import '../entities/producto.dart';

/// Contrato del repositorio de Productos (implementado en data/repositories).
abstract class ProductoRepository {
  Future<List<Producto>> obtenerTodos();
  Future<List<Producto>> buscar(String query);
  Future<Producto?> obtenerPorId(String id);
  Future<void> crear(Producto producto);
  Future<void> actualizar(Producto producto);
  Future<void> eliminar(String id);
  Stream<List<Producto>> observarTodos();
}
