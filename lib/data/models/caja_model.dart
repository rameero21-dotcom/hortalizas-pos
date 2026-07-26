import 'dart:convert';
import '../../domain/entities/caja.dart';

class MovimientoCajaModel extends MovimientoCaja {
  const MovimientoCajaModel({
    required super.id,
    required super.tipo,
    required super.monto,
    required super.detalle,
    required super.fecha,
    required super.usuarioId,
  });

  factory MovimientoCajaModel.fromMap(Map<String, dynamic> map) => MovimientoCajaModel(
        id: map['id'] as String,
        tipo: TipoMovimientoCaja.values.byName(map['tipo'] as String),
        monto: (map['monto'] as num).toDouble(),
        detalle: map['detalle'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        usuarioId: map['usuarioId'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo': tipo.name,
        'monto': monto,
        'detalle': detalle,
        'fecha': fecha.toIso8601String(),
        'usuarioId': usuarioId,
      };
}

class CierreCajaModel extends CierreCaja {
  const CierreCajaModel({
    required super.id,
    required super.fecha,
    required super.cajaInicio,
    required super.billetes,
    required super.usuarioId,
    super.nota,
  });

  /// Los billetes se guardan como JSON en una sola columna (una lista
  /// chica de objetos {denominacion, cantidad}, no necesita su propia
  /// tabla relacional).
  factory CierreCajaModel.fromMap(Map<String, dynamic> map) {
    final billetesRaw = jsonDecode(map['billetesJson'] as String) as List<dynamic>;
    final billetes = billetesRaw
        .map((b) => ConteoBillete(
              denominacion: b['denominacion'] as int,
              cantidad: b['cantidad'] as int,
            ))
        .toList();
    return CierreCajaModel(
      id: map['id'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      cajaInicio: (map['cajaInicio'] as num).toDouble(),
      billetes: billetes,
      usuarioId: map['usuarioId'] as String,
      nota: map['nota'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fecha': fecha.toIso8601String(),
        'cajaInicio': cajaInicio,
        'billetesJson': jsonEncode(billetes
            .map((b) => {'denominacion': b.denominacion, 'cantidad': b.cantidad})
            .toList()),
        'usuarioId': usuarioId,
        'nota': nota,
      };
}
