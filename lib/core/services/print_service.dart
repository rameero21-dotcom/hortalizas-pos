import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/entities/venta.dart';
import '../errors/exceptions.dart';
import '../utils/formatters.dart';
import 'qr_service.dart';

class ImpresoraDisponible {
  final String nombre;
  final String direccionMac;
  ImpresoraDisponible(this.nombre, this.direccionMac);
}

bool get _esDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

class PrintService {
  final QrService _qrService;
  PrintService(this._qrService);

  Future<List<ImpresoraDisponible>> buscarImpresorasDisponibles() async {
    final pareadas = await PrintBluetoothThermal.pairedBluetooths;
    return pareadas.map((d) => ImpresoraDisponible(d.name, d.macAdress)).toList();
  }

  Future<bool> conectar(String direccionMac) {
    return PrintBluetoothThermal.connect(macPrinterAddress: direccionMac);
  }

  Future<bool> hayImpresoraConectada() => PrintBluetoothThermal.connectionStatus;

  Future<void> desconectar() => PrintBluetoothThermal.disconnect;

  Future<void> imprimirTicket({
    required Venta venta,
    required String nombreComercio,
    bool ancho58mm = false,
  }) async {
    if (_esDesktop) {
      await _imprimirTicketDesktop(venta: venta, nombreComercio: nombreComercio);
    } else {
      await _imprimirTicketBluetooth(venta: venta, nombreComercio: nombreComercio, ancho58mm: ancho58mm);
    }
  }

  Future<void> _imprimirTicketBluetooth({
    required Venta venta,
    required String nombreComercio,
    required bool ancho58mm,
  }) async {
    final conectado = await hayImpresoraConectada();
    if (!conectado) {
      throw PrinterException(
          'No hay ninguna impresora Bluetooth conectada. Emparejala en la '
          'configuración del celular y conectala desde Admin > Configuración.');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(ancho58mm ? PaperSize.mm58 : PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text(
      nombreComercio,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    );
    bytes += generator.text('Venta #${venta.numero}', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(Formatters.formatearFechaHora(venta.fecha),
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    for (final item in venta.detalle) {
      bytes += generator.row([
        PosColumn(text: item.nombreProducto, width: 6),
        PosColumn(
            text: '${item.cantidad}', width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(
            text: Formatters.formatearMoneda(item.precioTotal),
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.text(
      'TOTAL: ${Formatters.formatearMoneda(venta.total)}',
      styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2),
    );
    if (venta.metodoPago != null) {
      bytes += generator.text('Pago: ${venta.metodoPago!.name}',
          styles: const PosStyles(align: PosAlign.right));
    }

    bytes += generator.feed(1);
    bytes += generator.qrcode(_qrService.generarPayload(venta));
    bytes += generator.feed(2);
    bytes += generator.cut();

    final enviado = await PrintBluetoothThermal.writeBytes(bytes);
    if (!enviado) {
      throw PrinterException('La impresora no aceptó el ticket. Revisá que tenga papel y esté encendida.');
    }
  }

  Future<void> _imprimirTicketDesktop({
    required Venta venta,
    required String nombreComercio,
  }) async {
    final qrPayload = _qrService.generarPayload(venta);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(nombreComercio,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Venta #${venta.numero}'),
              pw.Text(Formatters.formatearFechaHora(venta.fecha)),
              pw.Divider(),
              ...venta.detalle.map((item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text(item.nombreProducto)),
                      pw.Text('${item.cantidad}'),
                      pw.SizedBox(width: 8),
                      pw.Text(Formatters.formatearMoneda(item.precioTotal)),
                    ],
                  )),
              pw.Divider(),
              pw.Text('TOTAL: ${Formatters.formatearMoneda(venta.total)}',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              if (venta.metodoPago != null) pw.Text('Pago: ${venta.metodoPago!.name}'),
              pw.SizedBox(height: 12),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrPayload,
                width: 120,
                height: 120,
              ),
            ],
          );
        },
      ),
    );

    final huboImpresora = await Printing.layoutPdf(onLayout: (_) => doc.save());
    if (!huboImpresora) {
      throw PrinterException(
          'No se completó la impresión (se canceló el diálogo o no hay impresora configurada en Windows).');
    }
  }
}