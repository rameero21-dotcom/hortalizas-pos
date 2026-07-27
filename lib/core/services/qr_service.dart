import 'dart:convert';
import '../../domain/entities/venta.dart';

/// Codifica y decodifica una Venta completa dentro de un QR,
/// para que la caja pueda reconstruir la venta sin conexión (solo respaldo).
class QrService {
  /// Genera el string JSON compacto que se codifica en el QR.
  String generarPayload(Venta venta) {
    final data = {
      'id': venta.id,
      'numero': venta.numero,
      'fecha': venta.fecha.toIso8601String(),
      'vendedorId': venta.vendedorId,
      'productos': venta.detalle
          .map((d) => {
                'productoId': d.productoId,
                'nombre': d.nombreProducto,
                'cantidad': d.cantidad,
                'precioTotal': d.precioTotal,
              })
          .toList(),
      'total': venta.total,
      'nombreCliente': venta.nombreCliente,
    };
    return jsonEncode(data);
  }

  /// Reconstruye los datos esenciales de la venta a partir del QR escaneado.
  Map<String, dynamic> decodificarPayload(String qrRaw) {
    return jsonDecode(qrRaw) as Map<String, dynamic>;
  }
}
