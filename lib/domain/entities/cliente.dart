/// Entidad de dominio: Cliente (preparado para uso futuro - cuenta corriente).
class Cliente {
  final String id;
  final String nombre;
  final String telefono;
  final String direccion;
  final double saldoCuentaCorriente;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    this.saldoCuentaCorriente = 0,
  });
}

/// Un cargo (deuda que aumenta) o un pago (deuda que baja) en la cuenta
/// corriente de un cliente. Ej: "fiado" una venta -> cargo; el cliente
/// paga o transfiere -> pago.
enum TipoMovimientoCuenta { cargo, pago }

class MovimientoCuentaCorriente {
  final String id;
  final String clienteId;
  final TipoMovimientoCuenta tipo;
  final double monto;
  final String detalle;
  final DateTime fecha;
  final String usuarioId;

  const MovimientoCuentaCorriente({
    required this.id,
    required this.clienteId,
    required this.tipo,
    required this.monto,
    required this.detalle,
    required this.fecha,
    required this.usuarioId,
  });
}
