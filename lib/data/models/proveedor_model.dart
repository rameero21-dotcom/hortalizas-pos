import '../../domain/entities/proveedor.dart';

class ProveedorModel extends Proveedor {
  const ProveedorModel({
    required super.id,
    required super.nombre,
    super.telefono,
    super.activo,
    super.saldoCuentaCorriente,
  });

  factory ProveedorModel.fromMap(Map<String, dynamic> map) => ProveedorModel(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        telefono: map['telefono'] as String? ?? '',
        activo: _parseBool(map['activo'], porDefecto: true),
        saldoCuentaCorriente: (map['saldoCuentaCorriente'] as num?)?.toDouble() ?? 0,
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
        'telefono': telefono,
        'activo': activo ? 1 : 0,
        'saldoCuentaCorriente': saldoCuentaCorriente,
      };

  factory ProveedorModel.fromEntity(Proveedor p) => ProveedorModel(
        id: p.id,
        nombre: p.nombre,
        telefono: p.telefono,
        activo: p.activo,
        saldoCuentaCorriente: p.saldoCuentaCorriente,
      );
}

class PedidoProveedorModel extends PedidoProveedor {
  const PedidoProveedorModel({
    required super.id,
    required super.proveedorId,
    super.productoId,
    required super.productoNombre,
    required super.cantidad,
    required super.metodoPago,
    required super.monto,
    required super.fecha,
    required super.usuarioId,
    super.nota,
  });

  factory PedidoProveedorModel.fromMap(Map<String, dynamic> map) => PedidoProveedorModel(
        id: map['id'] as String,
        proveedorId: map['proveedorId'] as String,
        productoId: map['productoId'] as String?,
        productoNombre: map['productoNombre'] as String,
        cantidad: (map['cantidad'] as num).toDouble(),
        metodoPago: MetodoPagoProveedor.values.byName(map['metodoPago'] as String),
        monto: (map['monto'] as num).toDouble(),
        fecha: DateTime.parse(map['fecha'] as String),
        usuarioId: map['usuarioId'] as String,
        nota: map['nota'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'proveedorId': proveedorId,
        'productoId': productoId,
        'productoNombre': productoNombre,
        'cantidad': cantidad,
        'metodoPago': metodoPago.name,
        'monto': monto,
        'fecha': fecha.toIso8601String(),
        'usuarioId': usuarioId,
        'nota': nota,
      };
}

class PagoProveedorModel extends PagoProveedor {
  const PagoProveedorModel({
    required super.id,
    required super.proveedorId,
    required super.monto,
    required super.metodoPago,
    required super.fecha,
    required super.usuarioId,
    super.nota,
  });

  factory PagoProveedorModel.fromMap(Map<String, dynamic> map) => PagoProveedorModel(
        id: map['id'] as String,
        proveedorId: map['proveedorId'] as String,
        monto: (map['monto'] as num).toDouble(),
        metodoPago: MetodoPagoProveedor.values.byName(map['metodoPago'] as String),
        fecha: DateTime.parse(map['fecha'] as String),
        usuarioId: map['usuarioId'] as String,
        nota: map['nota'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'proveedorId': proveedorId,
        'monto': monto,
        'metodoPago': metodoPago.name,
        'fecha': fecha.toIso8601String(),
        'usuarioId': usuarioId,
        'nota': nota,
      };
}
