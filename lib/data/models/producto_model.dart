import '../../domain/entities/producto.dart';

/// Modelo de datos de Producto: agrega serialización SQLite/Firestore
/// sobre la entidad de dominio pura.
class ProductoModel extends Producto {
  const ProductoModel({
    required super.id,
    required super.nombre,
    required super.precioSugerido,
    required super.categoria,
    required super.activo,
    super.favorito,
  });

  /// Acepta tanto filas de SQLite (booleanos como 0/1) como futuros
  /// documentos de Firestore (booleanos reales true/false, Fase 4).
  factory ProductoModel.fromMap(Map<String, dynamic> map) => ProductoModel(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        precioSugerido: (map['precioSugerido'] as num).toDouble(),
        categoria: map['categoria'] as String,
        activo: _parseBool(map['activo'], porDefecto: true),
        favorito: _parseBool(map['favorito'], porDefecto: false),
      );

  static bool _parseBool(dynamic valor, {required bool porDefecto}) {
    if (valor == null) return porDefecto;
    if (valor is bool) return valor;
    if (valor is int) return valor == 1;
    return porDefecto;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'precioSugerido': precioSugerido,
        'categoria': categoria,
        'activo': activo ? 1 : 0,
        'favorito': favorito ? 1 : 0,
      };

  factory ProductoModel.fromEntity(Producto p) => ProductoModel(
        id: p.id,
        nombre: p.nombre,
        precioSugerido: p.precioSugerido,
        categoria: p.categoria,
        activo: p.activo,
        favorito: p.favorito,
      );
}
