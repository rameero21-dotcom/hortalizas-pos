import 'dart:convert';
import '../../domain/entities/venta.dart';
import '../../domain/entities/detalle_venta.dart';

/// Modelo de datos de Venta con serialización para SQLite/Firestore/QR.
class VentaModel extends Venta {
  const VentaModel({
    required super.id,
    required super.numero,
    required super.fecha,
    required super.vendedorId,
    super.vendedorNombre,
    required super.detalle,
    required super.total,
    super.estado,
    super.metodoPago,
    super.cajeroId,
    super.fechaCobro,
    super.clienteId,
    super.nombreCliente,
    super.pagos,
  });

  static List<DetallePago> _parsePagos(dynamic raw) {
    if (raw == null) return const [];
    final texto = raw is String ? raw : jsonEncode(raw);
    if (texto.isEmpty || texto == 'null') return const [];
    final lista = jsonDecode(texto) as List<dynamic>;
    return lista
        .map((p) => DetallePago(
              metodo: MetodoPago.values.byName(p['metodo'] as String),
              monto: (p['monto'] as num).toDouble(),
            ))
        .toList();
  }

  static dynamic _encodePagos(List<DetallePago> pagos) {
    return pagos.map((p) => {'metodo': p.metodo.name, 'monto': p.monto}).toList();
  }

  factory VentaModel.fromMap(Map<String, dynamic> map, List<DetalleVenta> detalle) => VentaModel(
        id: map['id'] as String,
        numero: map['numero'] as int,
        fecha: DateTime.parse(map['fecha'] as String),
        vendedorId: map['vendedorId'] as String,
        vendedorNombre: map['vendedorNombre'] as String?,
        detalle: detalle,
        total: (map['total'] as num).toDouble(),
        estado: EstadoVenta.values.byName(map['estado'] as String? ?? 'pendiente'),
        metodoPago: map['metodoPago'] != null
            ? MetodoPago.values.byName(map['metodoPago'] as String)
            : null,
        cajeroId: map['cajeroId'] as String?,
        fechaCobro: map['fechaCobro'] != null ? DateTime.parse(map['fechaCobro'] as String) : null,
        clienteId: map['clienteId'] as String?,
        nombreCliente: map['nombreCliente'] as String?,
        pagos: _parsePagos(map['pagos']),
      );

  /// Reconstruye la venta a partir de un documento de Firestore, donde
  /// el detalle viene embebido como array (ver `toRemoteMap`).
  factory VentaModel.fromRemoteMap(Map<String, dynamic> map) {
    final detalleRaw = (map['detalle'] as List<dynamic>? ?? []);
    final detalle = detalleRaw
        .map((d) => DetalleVenta(
              productoId: d['productoId'] as String,
              nombreProducto: d['nombreProducto'] as String,
              cantidad: (d['cantidad'] as num).toDouble(),
              precioTotal: (d['precioTotal'] as num).toDouble(),
            ))
        .toList();
    return VentaModel.fromMap(map, detalle);
  }

  /// Para SQLite: los pagos se guardan como texto JSON en una sola columna.
  Map<String, dynamic> toMap() => {
        'id': id,
        'numero': numero,
        'fecha': fecha.toIso8601String(),
        'vendedorId': vendedorId,
        'vendedorNombre': vendedorNombre,
        'total': total,
        'estado': estado.name,
        'metodoPago': metodoPago?.name,
        'cajeroId': cajeroId,
        'fechaCobro': fechaCobro?.toIso8601String(),
        'clienteId': clienteId,
        'nombreCliente': nombreCliente,
        'pagos': jsonEncode(_encodePagos(pagos)),
      };

  /// Para Firestore: a diferencia de SQLite (donde el detalle vive en su
  /// propia tabla), acá se embebe como array dentro del mismo documento
  /// para que la caja pueda reconstruir la venta completa con una sola
  /// lectura (igual que reconstruyendo desde el QR). Los pagos también
  /// van embebidos como array (no como texto JSON, Firestore los guarda
  /// nativamente).
  Map<String, dynamic> toRemoteMap() => {
        ...toMap(),
        'pagos': _encodePagos(pagos),
        'detalle': detalle
            .map((d) => {
                  'productoId': d.productoId,
                  'nombreProducto': d.nombreProducto,
                  'cantidad': d.cantidad,
                  'precioTotal': d.precioTotal,
                })
            .toList(),
      };
}
