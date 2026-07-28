/// Entidad de dominio: Producto del catálogo (papa, cebolla, etc.).
///
/// [costoUnitario] se usa para calcular margen y utilidad real por venta.
/// [tasaIIBB]/[tasaTSH] quedan en el modelo por compatibilidad con datos
/// viejos, pero YA NO se usan: esos impuestos se calculan automáticamente
/// como porcentaje de la venta (ver ConfiguracionImpuestos), igual que en
/// la planilla de control diario, en vez de cargarse por producto.
class Producto {
  final String id;
  final String nombre;
  final double precioSugerido;
  final String categoria;
  final bool activo;
  final bool favorito;

  /// Costo de compra por unidad (bulto/kg/unidad, según cómo se mida
  /// el producto). Se usa para calcular margen y utilidad.
  final double costoUnitario;

  /// Ingresos Brutos: importe fijo por unidad vendida (tal como se ve
  /// en la planilla, no es un porcentaje sino un monto por unidad).
  final double tasaIIBB;

  /// Tasa de Seguridad e Higiene: mismo criterio que IIBB, importe
  /// fijo por unidad vendida.
  final double tasaTSH;

  const Producto({
    required this.id,
    required this.nombre,
    required this.precioSugerido,
    required this.categoria,
    required this.activo,
    this.favorito = false,
    this.costoUnitario = 0,
    this.tasaIIBB = 0,
    this.tasaTSH = 0,
  });

  Producto copyWith({
    String? id,
    String? nombre,
    double? precioSugerido,
    String? categoria,
    bool? activo,
    bool? favorito,
    double? costoUnitario,
    double? tasaIIBB,
    double? tasaTSH,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precioSugerido: precioSugerido ?? this.precioSugerido,
      categoria: categoria ?? this.categoria,
      activo: activo ?? this.activo,
      favorito: favorito ?? this.favorito,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      tasaIIBB: tasaIIBB ?? this.tasaIIBB,
      tasaTSH: tasaTSH ?? this.tasaTSH,
    );
  }
}
