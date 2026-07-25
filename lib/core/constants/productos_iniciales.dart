import '../../domain/entities/producto.dart';

/// Productos iniciales precargados según el pedido original.
/// Se insertan una única vez en el primer arranque de la app (ver DatabaseSeeder).
final List<Producto> productosIniciales = [
  Producto(id: '', nombre: 'Papa', precioSugerido: 0, categoria: 'Verduras', activo: true),
  Producto(id: '', nombre: 'Batata', precioSugerido: 0, categoria: 'Verduras', activo: true),
  Producto(id: '', nombre: 'Cebolla', precioSugerido: 0, categoria: 'Verduras', activo: true),
  Producto(id: '', nombre: 'Zanahoria', precioSugerido: 0, categoria: 'Verduras', activo: true),
  Producto(id: '', nombre: 'Anco', precioSugerido: 0, categoria: 'Verduras', activo: true),
  Producto(id: '', nombre: 'Cautiá', precioSugerido: 0, categoria: 'Verduras', activo: true),
  Producto(id: '', nombre: 'Ajo', precioSugerido: 0, categoria: 'Verduras', activo: true),
];
