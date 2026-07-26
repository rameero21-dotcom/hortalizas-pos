/// Entidad de dominio: stock actual de un producto.
class Stock {
  final String productoId;
  final double cantidadDisponible;
  final double umbralStockBajo;

  const Stock({
    required this.productoId,
    required this.cantidadDisponible,
    required this.umbralStockBajo,
  });

  bool get stockBajo => cantidadDisponible <= umbralStockBajo;
}

enum TipoMovimientoStock { ingreso, ventaDescuento, ajusteManual, merma }

/// Registro histórico de movimientos de stock (para el historial/auditoría).
class MovimientoStock {
  final String id;
  final String productoId;
  final TipoMovimientoStock tipo;
  final double cantidad; // positivo = ingreso, negativo = egreso
  final DateTime fecha;
  final String usuarioId;
  final String? nota;

  const MovimientoStock({
    required this.id,
    required this.productoId,
    required this.tipo,
    required this.cantidad,
    required this.fecha,
    required this.usuarioId,
    this.nota,
  });
}
