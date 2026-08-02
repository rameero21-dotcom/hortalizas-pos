/// Entidad de dominio: Proveedor (de quién se compra mercadería).
/// saldoCuentaCorriente: positivo = le debemos plata (pedimos más de lo
/// que le pagamos hasta ahora); 0 = estamos al día.
class Proveedor {
  final String id;
  final String nombre;
  final String telefono;
  final bool activo;
  final double saldoCuentaCorriente;

  const Proveedor({
    required this.id,
    required this.nombre,
    this.telefono = '',
    this.activo = true,
    this.saldoCuentaCorriente = 0,
  });

  Proveedor copyWith({String? nombre, String? telefono, bool? activo, double? saldoCuentaCorriente}) {
    return Proveedor(
      id: id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      activo: activo ?? this.activo,
      saldoCuentaCorriente: saldoCuentaCorriente ?? this.saldoCuentaCorriente,
    );
  }
}

/// Cómo se le pagó al proveedor un pedido puntual.
enum MetodoPagoProveedor { efectivo, transferencia, cheque }

/// Un pedido/compra hecho a un proveedor: qué producto, cuánto se pidió,
/// y a qué precio unitario. "productoId" es opcional: si el producto ya
/// existe en el catálogo se puede vincular, o cargarse como texto
/// libre (ej: algo que se compra pero no se vende, como bolsas o cajones).
/// El monto total del pedido es siempre cantidad × precioUnitario (como
/// una calculadora), nunca se carga a mano.
class PedidoProveedor {
  final String id;
  final String proveedorId;
  final String? productoId;
  final String productoNombre;
  final double cantidad;
  final double precioUnitario;
  final DateTime fecha;
  final String usuarioId;
  final String? nota;

  const PedidoProveedor({
    required this.id,
    required this.proveedorId,
    this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.fecha,
    required this.usuarioId,
    this.nota,
  });

  double get monto => cantidad * precioUnitario;
}

/// Un pago hecho al proveedor (para saldar lo que se le debe). Cada
/// pedido SUMA a la deuda con el proveedor; cada pago la RESTA.
class PagoProveedor {
  final String id;
  final String proveedorId;
  final double monto;
  final MetodoPagoProveedor metodoPago;
  final DateTime fecha;
  final String usuarioId;
  final String? nota;

  const PagoProveedor({
    required this.id,
    required this.proveedorId,
    required this.monto,
    required this.metodoPago,
    required this.fecha,
    required this.usuarioId,
    this.nota,
  });
}
