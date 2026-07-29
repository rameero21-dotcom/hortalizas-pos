/// Cantidad de billetes de una denominación específica, tal como se
/// cuenta el efectivo físico en la planilla (20000, 10000, 2000, 1000,
/// 500, 100, etc.).
class ConteoBillete {
  final int denominacion;
  final int cantidad;

  const ConteoBillete({required this.denominacion, required this.cantidad});

  double get subtotal => (denominacion * cantidad).toDouble();
}

/// Un movimiento manual de efectivo dentro de la caja del día (ingreso
/// o egreso), distinto de las ventas cobradas normales. Ej: un cliente
/// que paga una deuda vieja, un gasto en efectivo, un préstamo, etc.
enum TipoMovimientoCaja { ingreso, egreso }

/// Cómo entró/salió la plata de este movimiento. Los egresos son
/// siempre en efectivo (no tiene sentido "un gasto por transferencia"
/// para el arqueo físico); los ingresos sí pueden ser por transferencia
/// (ej: alguien te transfiere en vez de traer el efectivo), aunque lo
/// más común sea efectivo.
enum MetodoMovimientoCaja { efectivo, transferencia }

class MovimientoCaja {
  final String id;
  final TipoMovimientoCaja tipo;
  final double monto;
  final String detalle;
  final DateTime fecha;
  final String usuarioId;
  final MetodoMovimientoCaja metodo;

  const MovimientoCaja({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.detalle,
    required this.fecha,
    required this.usuarioId,
    this.metodo = MetodoMovimientoCaja.efectivo,
  });
}

/// Cierre/arqueo de caja de un turno o día: cuánto efectivo había al
/// empezar (piso), el conteo de billetes al cerrar, y el resumen para
/// compararlo contra lo que el sistema calcula que debería haber
/// (ventas en efectivo + ingresos manuales - egresos manuales).
class CierreCaja {
  final String id;
  final DateTime fecha;
  final double cajaInicio;
  final List<ConteoBillete> billetes;
  final String usuarioId;
  final String? nota;

  const CierreCaja({
    required this.id,
    required this.fecha,
    required this.cajaInicio,
    required this.billetes,
    required this.usuarioId,
    this.nota,
  });

  /// Total contado físicamente en efectivo (suma de billetes).
  double get totalContado => billetes.fold(0.0, (acc, b) => acc + b.subtotal);
}
