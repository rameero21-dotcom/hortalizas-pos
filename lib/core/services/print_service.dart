import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../domain/entities/venta.dart';
import '../errors/exceptions.dart';
import '../utils/formatters.dart';
import 'qr_service.dart';

/// Impresora térmica Bluetooth ya emparejada por el sistema operativo.
class ImpresoraDisponible {
  final String nombre;
  final String direccionMac;
  ImpresoraDisponible(this.nombre, this.direccionMac);
}

/// Servicio de impresión de tickets en impresoras térmicas 58mm / 80mm
/// (Bluetooth), usando esc_pos_utils_plus para armar el ticket y
/// print_bluetooth_thermal para mandarlo por Bluetooth.
///
/// NOTA: los nombres exactos de métodos de estos paquetes pueden variar
/// levemente entre versiones. Si al compilar aparece un error de "método
/// no encontrado" en este archivo, revisar la documentación de la versión
/// instalada (`flutter pub deps` o pub.dev) y ajustar el nombre puntual;
/// la lógica general (conectar -> generar bytes -> escribir) no cambia.
class PrintService {
  final QrService _qrService;
  PrintService(this._qrService);

  /// Lista las impresoras Bluetooth ya emparejadas desde la configuración
  /// del celular (emparejalas ahí antes de buscarlas acá).
  Future<List<ImpresoraDisponible>> buscarImpresorasDisponibles() async {
    final pareadas = await PrintBluetoothThermal.pairedBluetooths;
    return pareadas.map((d) => ImpresoraDisponible(d.name, d.macAdress)).toList();
  }

  Future<bool> conectar(String direccionMac) {
    return PrintBluetoothThermal.connect(macPrinterAddress: direccionMac);
  }

  Future<bool> hayImpresoraConectada() => PrintBluetoothThermal.connectionStatus;

  Future<void> desconectar() => PrintBluetoothThermal.disconnect;

  /// Imprime el ticket de una venta ya cobrada.
  /// [ancho58mm]: true para papel de 58mm, false para 80mm.
  Future<void> imprimirTicket({
    required Venta venta,
    required String nombreComercio,
    bool ancho58mm = false,
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
}
