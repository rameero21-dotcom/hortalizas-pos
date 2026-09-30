import '../entities/proveedor.dart';

abstract class ProveedorRepository {
  Future<List<Proveedor>> obtenerTodos();

  /// Stream en tiempo real de la lista de proveedores.
  Stream<List<Proveedor>> observarTodos();
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

  /// Elimina el pedido y DEVUELVE su monto al saldo (lo que le debemos
  /// baja en esa misma medida, ya que el pedido lo había sumado).
  Future<void> eliminarPedido(String id, {required String proveedorId, required double monto});

  /// Edita un pedido ya cargado (producto/cantidad/precio). Recalcula
  /// el saldo del proveedor por la diferencia entre el monto viejo y
  /// el nuevo.
  Future<void> editarPedido(PedidoProveedor pedido);

  /// Registra un pago al proveedor: RESTA el monto del saldo (lo que
  /// le debemos baja).
  Future<void> registrarPago(PagoProveedor pago);

  /// Elimina el pago y DEVUELVE su monto al saldo (lo que le debemos
  /// sube en esa misma medida, ya que el pago lo había restado).
  Future<void> eliminarPago(String id, {required String proveedorId, required double monto});
  Future<List<PagoProveedor>> obtenerPagos(String proveedorId);
  Future<List<PagoProveedor>> obtenerTodosLosPagosGlobal();
}
