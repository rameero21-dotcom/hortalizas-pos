/// Entidad de dominio: Producto del catálogo (papa, cebolla, etc.).
class Producto {
  final String id;
  final String nombre;
  final double precioSugerido;
  final String categoria;
  final bool activo;
  final bool favorito;

  const Producto({
    required this.id,
    required this.nombre,
    required this.precioSugerido,
    required this.categoria,
    required this.activo,
    this.favorito = false,
  });

  Producto copyWith({
    String? id,
    String? nombre,
    double? precioSugerido,
    String? categoria,
    bool? activo,
    bool? favorito,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precioSugerido: precioSugerido ?? this.precioSugerido,
      categoria: categoria ?? this.categoria,
      activo: activo ?? this.activo,
      favorito: favorito ?? this.favorito,
    );
  }
}
