import 'dart:convert';
import '../../domain/entities/venta.dart';

/// Codifica y decodifica una Venta completa dentro de un QR, para que
/// la caja pueda reconstruir la venta sin conexión (solo respaldo) —
/// y, ahora también, para que quepa en el comando nativo de QR de la
/// impresora térmica (que tiene un límite chico de bytes; por eso las
/// claves son cortas y la fecha va como número, no como texto ISO).
class QrService {
  /// Genera el string JSON compacto que se codifica en el QR.
  String generarPayload(Venta venta) {
    final data = {
      'i': venta.id,
      'n': venta.numero,
      'f': venta.fecha.millisecondsSinceEpoch,
      'v': venta.vendedorId,
      'vn': venta.vendedorNombre,
      'p': venta.detalle
          .map((d) => {
                'pi': d.productoId,
                'pn': d.nombreProducto,
                'c': d.cantidad,
                'pt': d.precioTotal,
              })
          .toList(),
      't': venta.total,
      'nc': venta.nombreCliente,
    };
    return jsonEncode(data);
  }

  /// Reconstruye los datos esenciales de la venta a partir del QR escaneado.
  Map<String, dynamic> decodificarPayload(String qrRaw) {
    return jsonDecode(qrRaw) as Map<String, dynamic>;
  }
}
