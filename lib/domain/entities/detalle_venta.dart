/// Ítem individual dentro de una venta: producto + cantidad + precio TOTAL
/// (no precio unitario, según especificación del negocio).
class DetalleVenta {
  final String productoId;
  final String nombreProducto;
  final double cantidad;
  final double precioTotal;

  const DetalleVenta({
    required this.productoId,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioTotal,
  });
}
