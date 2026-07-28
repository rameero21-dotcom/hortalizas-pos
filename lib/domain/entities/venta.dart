import 'detalle_venta.dart';

enum MetodoPago { efectivo, transferencia, debito, credito, cuentaCorriente }

enum EstadoVenta { pendiente, cobrada, cancelada }

/// Un pago parcial dentro de una venta cobrada con más de un método
/// (ej: $30.000 en efectivo + $70.000 por transferencia para una venta
/// de $100.000).
class DetallePago {
  final MetodoPago metodo;
  final double monto;

  const DetallePago({required this.metodo, required this.monto});
}

/// Entidad de dominio: una Venta generada por el vendedor,
/// pendiente de cobro en caja.
class Venta {
  final String id;
  final int numero;
  final DateTime fecha;
  final String vendedorId;

  /// Nombre del vendedor que creó la venta, guardado en el momento (no
  /// se resuelve después por id) para poder mostrarlo junto al número
  /// de venta y distinguir boletas si más de un vendedor usa la app al
  /// mismo tiempo (el número de venta se calcula por dispositivo, así
  /// que en ese caso raro dos ventas distintas podrían compartir
  /// número).
  final String? vendedorNombre;
  final List<DetalleVenta> detalle;
  final double total;
  final EstadoVenta estado;
  final MetodoPago? metodoPago;
  final String? cajeroId;
  final DateTime? fechaCobro;

  /// Cliente al que se le carga la venta (solo cuando metodoPago es
  /// cuentaCorriente, ej. "fiado").
  final String? clienteId;

  /// Nombre/etiqueta que carga el vendedor para identificar la boleta
  /// en caja (ej: "Juan", "Mesa 3"). Es solo un texto libre, no tiene
  /// por qué corresponder a un Cliente formal del sistema.
  final String? nombreCliente;

  /// Cuando la venta se cobra con más de un método de pago a la vez,
  /// acá queda el detalle de cada parte (la suma debe dar `total`).
  /// Si la venta se cobró con un solo método, esta lista tiene un solo
  /// elemento igual a [metodoPago]/[total].
  final List<DetallePago> pagos;

  const Venta({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.vendedorId,
    this.vendedorNombre,
    required this.detalle,
    required this.total,
    this.estado = EstadoVenta.pendiente,
    this.metodoPago,
    this.cajeroId,
    this.fechaCobro,
    this.clienteId,
    this.nombreCliente,
    this.pagos = const [],
  });

  Venta copyWith({
    EstadoVenta? estado,
    MetodoPago? metodoPago,
    String? cajeroId,
    DateTime? fechaCobro,
    String? clienteId,
    String? nombreCliente,
    List<DetallePago>? pagos,
  }) {
    return Venta(
      id: id,
      numero: numero,
      fecha: fecha,
      vendedorId: vendedorId,
      vendedorNombre: vendedorNombre,
      detalle: detalle,
      total: total,
      estado: estado ?? this.estado,
      metodoPago: metodoPago ?? this.metodoPago,
      cajeroId: cajeroId ?? this.cajeroId,
      fechaCobro: fechaCobro ?? this.fechaCobro,
      clienteId: clienteId ?? this.clienteId,
      nombreCliente: nombreCliente ?? this.nombreCliente,
      pagos: pagos ?? this.pagos,
    );
  }
}
