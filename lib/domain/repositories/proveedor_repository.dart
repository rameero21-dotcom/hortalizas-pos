import '../entities/proveedor.dart';

abstract class ProveedorRepository {
  Future<List<Proveedor>> obtenerTodos();
  Future<void> crear(Proveedor proveedor);
  Future<void> actualizar(Proveedor proveedor);
  Future<void> eliminar(String id);

  /// Trae proveedores desde Firestore y actualiza la caché local
  /// (mismo criterio que ClienteRepository/ProductoRepository).
  Future<void> refrescarDesdeRemoto();

  /// Pedidos hechos a UN proveedor puntual (lectura local).
  Future<List<PedidoProveedor>> obtenerPedidos(String proveedorId);

  /// Todos los pedidos de todos los proveedores, sin importar el
  /// dispositivo. Requiere conexión.
  Future<List<PedidoProveedor>> obtenerTodosLosPedidosGlobal();

  Future<void> registrarPedido(PedidoProveedor pedido);
  Future<void> eliminarPedido(String id);
}
