import '../../domain/entities/cliente.dart';

class ClienteModel extends Cliente {
  const ClienteModel({
    required super.id,
    required super.nombre,
    required super.telefono,
    required super.direccion,
    super.saldoCuentaCorriente,
  });

  factory ClienteModel.fromMap(Map<String, dynamic> map) => ClienteModel(
        id: map['id'] as String,
        nombre: map['nombre'] as String? ?? '(sin nombre)',
        telefono: map['telefono'] as String? ?? '',
        direccion: map['direccion'] as String? ?? '',
        saldoCuentaCorriente: (map['saldoCuentaCorriente'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'telefono': telefono,
        'direccion': direccion,
        'saldoCuentaCorriente': saldoCuentaCorriente,
      };
}

class MovimientoCuentaCorrienteModel extends MovimientoCuentaCorriente {
  const MovimientoCuentaCorrienteModel({
    required super.id,
    required super.clienteId,
    required super.tipo,
    required super.monto,
    required super.detalle,
    required super.fecha,
    required super.usuarioId,
  });

  factory MovimientoCuentaCorrienteModel.fromMap(Map<String, dynamic> map) =>
      MovimientoCuentaCorrienteModel(
        id: map['id'] as String,
        clienteId: map['clienteId'] as String,
        tipo: TipoMovimientoCuenta.values.byName(map['tipo'] as String),
        monto: (map['monto'] as num).toDouble(),
        detalle: map['detalle'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        usuarioId: map['usuarioId'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'clienteId': clienteId,
        'tipo': tipo.name,
        'monto': monto,
        'detalle': detalle,
        'fecha': fecha.toIso8601String(),
        'usuarioId': usuarioId,
      };
}
