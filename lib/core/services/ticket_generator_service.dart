import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../domain/entities/venta.dart';
import 'qr_service.dart';
import '../utils/formatters.dart';

/// Arma el contenido del ticket (texto + QR) en formato ESC/POS listo
/// para mandar a la impresora térmica de 80mm.
class TicketGeneratorService {
  static Future<List<int>> generarTicketVenta(Venta venta, {bool incluirQr = true}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    var bytes = <int>[];

    bytes += generator.text(
      'C&S Hortalizas',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text('Pesadas', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    bytes += generator.text('Venta #${venta.numero}', styles: const PosStyles(bold: true));
    bytes += generator.text(Formatters.formatearFechaHora(venta.fecha));
    if (venta.vendedorNombre != null) {
      bytes += generator.text('Vendedor: ${venta.vendedorNombre}');
    }
    if (venta.nombreCliente != null && venta.nombreCliente!.isNotEmpty) {
      bytes += generator.text('Cliente: ${venta.nombreCliente}');
    }
    bytes += generator.hr();

    for (final d in venta.detalle) {
      bytes += generator.text(d.nombreProducto, styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: 'Cant: ${Formatters.formatearCantidad(d.cantidad)}', width: 6),
        PosColumn(
          text: Formatters.formatearMoneda(d.precioTotal),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: Formatters.formatearMoneda(venta.total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2),
      ),
    ]);

    if (venta.pagos.isNotEmpty) {
      bytes += generator.feed(1);
      for (final p in venta.pagos) {
        bytes += generator.text('${_labelMetodo(p.metodo)}: ${Formatters.formatearMoneda(p.monto)}');
      }
    } else if (venta.metodoPago != null) {
      bytes += generator.text('Pago: ${_labelMetodo(venta.metodoPago!)}');
    }

    bytes += generator.feed(1);
    bytes += generator.text(
      '¡Gracias por su compra!',
      styles: const PosStyles(align: PosAlign.center),
    );

    // El mismo QR que se usa como respaldo offline: si el ticket tiene
    // el QR igual sirve para que caja lo escanee si hiciera falta. Solo
    // va en la primera copia (las otras dos son solo para archivo).
    if (incluirQr) {
      final qrPayload = QrService().generarPayload(venta);
      bytes += generator.feed(1);
      bytes += generator.qrcode(qrPayload, align: PosAlign.center, size: QRSize.size6);
    }

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  static String _labelMetodo(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.transferencia => 'Transferencia',
        MetodoPago.debito => 'Débito',
        MetodoPago.credito => 'Crédito',
        MetodoPago.cuentaCorriente => 'Cuenta corriente',
      };
}
