import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:qr/qr.dart';
import 'package:image/image.dart' as img;
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
          text: _moneda(d.precioTotal),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: _moneda(venta.total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2),
      ),
    ]);

    bytes += generator.feed(1);
    bytes += generator.text(
      '¡Gracias por su compra!',
      styles: const PosStyles(align: PosAlign.center),
    );

    if (incluirQr) {
      final qrPayload = QrService().generarPayload(venta);
      bytes += generator.feed(1);
      try {
        // El QR se arma como imagen (bitmap) en vez de usar el comando
        // nativo de QR de la impresora — ese comando tiene un límite de
        // bytes bastante chico según el modelo, y si el contenido no
        // entra, la impresora tira el resto como texto suelto en vez
        // del código. Como imagen no hay ese límite: solo depende del
        // ancho del papel.
        final imagenQr = _generarImagenQr(qrPayload);
        bytes += generator.image(imagenQr);
      } catch (_) {
        // Si por lo que sea no se pudo generar la imagen, mejor
        // seguir sin el QR que arruinar el resto del ticket.
      }
    }

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  /// Genera el QR como imagen monocromática (blanco y negro), agrandada
  /// varias veces para que se vea nítida al imprimirse.
  static img.Image _generarImagenQr(String contenido) {
    final qrCode = QrCode.fromData(data: contenido, errorCorrectLevel: QrErrorCorrectLevel.M);
    final qrImage = QrImage(qrCode);

    const escala = 6; // cuántos píxeles ocupa cada "módulo" del QR
    const margen = 2; // módulos de margen blanco alrededor
    final ladoModulos = qrImage.moduleCount + margen * 2;
    final ladoPixeles = ladoModulos * escala;

    final imagen = img.Image(width: ladoPixeles, height: ladoPixeles);
    img.fill(imagen, color: img.ColorRgb8(255, 255, 255));

    for (var x = 0; x < qrImage.moduleCount; x++) {
      for (var y = 0; y < qrImage.moduleCount; y++) {
        if (qrImage.isDark(y, x)) {
          final px0 = (x + margen) * escala;
          final py0 = (y + margen) * escala;
          img.fillRect(
            imagen,
            x1: px0,
            y1: py0,
            x2: px0 + escala - 1,
            y2: py0 + escala - 1,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
      }
    }
    return imagen;
  }

  /// Formato de moneda propio para el ticket: solo ASCII (nada de
  /// espacios "no separables" ni símbolos raros que la impresora
  /// térmica no sepa interpretar y termine imprimiendo como letras
  /// sueltas, ej: "30.000á$" en vez de "$30.000").
  static String _moneda(num valor) {
    final entero = valor.round();
    final texto = entero.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      final posDesdeElFinal = texto.length - i;
      if (i > 0 && posDesdeElFinal % 3 == 0) buffer.write('.');
      buffer.write(texto[i]);
    }
    return '\$$buffer';
  }
}
