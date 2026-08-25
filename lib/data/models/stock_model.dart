import '../../domain/entities/stock.dart';

class StockModel extends Stock {
  const StockModel({
    required super.productoId,
    required super.cantidadDisponible,
    required super.umbralStockBajo,
  });

  /// [idDocumento] es un respaldo por si el documento quedó corrupto (sin
  /// el campo "productoId" adentro) — pasó con algunos productos que se
  /// crearon por primera vez con un incremento atómico antes de que ese
  /// campo se empezara a guardar ahí también. El id del documento en
  /// Firestore siempre ES el productoId (así están armados), así que
  /// sirve como respaldo seguro.
  factory StockModel.fromMap(Map<String, dynamic> map, {String? idDocumento}) => StockModel(
        productoId: (map['productoId'] as String?) ?? idDocumento ?? '',
        cantidadDisponible: (map['cantidadDisponible'] as num?)?.toDouble() ?? 0,
        umbralStockBajo: (map['umbralStockBajo'] as num?)?.toDouble() ?? 10.0,
      );

  Map<String, dynamic> toMap() => {
        'productoId': productoId,
        'cantidadDisponible': cantidadDisponible,
        'umbralStockBajo': umbralStockBajo,
      };
}

class MovimientoStockModel extends MovimientoStock {
  const MovimientoStockModel({
    required super.id,
    required super.productoId,
    required super.tipo,
    required super.cantidad,
    required super.fecha,
    required super.usuarioId,
    super.nota,
  });

  factory MovimientoStockModel.fromMap(Map<String, dynamic> map) => MovimientoStockModel(
        id: map['id'] as String,
        productoId: map['productoId'] as String,
        tipo: TipoMovimientoStock.values.byName(map['tipo'] as String),
        cantidad: (map['cantidad'] as num).toDouble(),
        fecha: DateTime.parse(map['fecha'] as String),
        usuarioId: map['usuarioId'] as String,
        nota: map['nota'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'productoId': productoId,
        'tipo': tipo.name,
        'cantidad': cantidad,
        'fecha': fecha.toIso8601String(),
        'usuarioId': usuarioId,
        'nota': nota,
      };
}
