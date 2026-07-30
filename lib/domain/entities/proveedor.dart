/// Entidad de dominio: Proveedor (de quién se compra mercadería).
class Proveedor {
  final String id;
  final String nombre;
  final String telefono;
  final bool activo;

  const Proveedor({
    required this.id,
    required this.nombre,
    this.telefono = '',
    this.activo = true,
  });

  Proveedor copyWith({String? nombre, String? telefono, bool? activo}) {
    return Proveedor(
      id: id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      activo: activo ?? this.activo,
    );
  }
}

/// Cómo se le pagó al proveedor un pedido puntual.
enum MetodoPagoProveedor { efectivo, transferencia, cheque }

/// Un pedido/compra hecho a un proveedor: qué producto, cuánto se pidió,
/// y cómo se le abonó. "productoId" es opcional: si el producto ya
/// existe en el catálogo se puede vincular, o cargarse como texto
/// libre (ej: algo que se compra pero no se vende, como bolsas o cajones).
class PedidoProveedor {
  final String id;
  final String proveedorId;
  final String? productoId;
  final String productoNombre;
  final double cantidad;
  final MetodoPagoProveedor metodoPago;
  final double monto;
  final DateTime fecha;
  final String usuarioId;
  final String? nota;

  const PedidoProveedor({
    required this.id,
    required this.proveedorId,
    this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.metodoPago,
    required this.monto,
    required this.fecha,
    required this.usuarioId,
    this.nota,
  });
}
