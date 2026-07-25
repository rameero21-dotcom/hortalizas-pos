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
        nombre: map['nombre'] as String,
        telefono: map['telefono'] as String,
        direccion: map['direccion'] as String,
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
