import 'detalle_venta.dart';

enum MetodoPago { efectivo, transferencia, debito, credito }

enum EstadoVenta { pendiente, cobrada, cancelada }

/// Entidad de dominio: una Venta generada por el vendedor,
/// pendiente de cobro en caja.
class Venta {
  final String id;
  final int numero;
  final DateTime fecha;
  final String vendedorId;
  final List<DetalleVenta> detalle;
  final double total;
  final EstadoVenta estado;
  final MetodoPago? metodoPago;
  final String? cajeroId;
  final DateTime? fechaCobro;

  const Venta({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.vendedorId,
    required this.detalle,
    required this.total,
    this.estado = EstadoVenta.pendiente,
    this.metodoPago,
    this.cajeroId,
    this.fechaCobro,
  });

  Venta copyWith({
    EstadoVenta? estado,
    MetodoPago? metodoPago,
    String? cajeroId,
    DateTime? fechaCobro,
  }) {
    return Venta(
      id: id,
      numero: numero,
      fecha: fecha,
      vendedorId: vendedorId,
      detalle: detalle,
      total: total,
      estado: estado ?? this.estado,
      metodoPago: metodoPago ?? this.metodoPago,
      cajeroId: cajeroId ?? this.cajeroId,
      fechaCobro: fechaCobro ?? this.fechaCobro,
    );
  }
}
