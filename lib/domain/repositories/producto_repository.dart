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

  /// Trae la lista completa de productos (y su stock) desde Firestore y
  /// actualiza la caché local SQLite. Se usa para el refresh manual
  /// (swipe-to-refresh en Android, botón "Actualizar" en Windows) que
  /// resuelve la demora de ver cambios hechos desde otro dispositivo.
  /// Si no hay conexión, no hace nada (la app sigue funcionando con lo
  /// que ya tenía en la caché local).
  Future<void> refrescarDesdeRemoto();
}
