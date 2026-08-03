import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Maneja la impresión por Bluetooth (celular/tablet Android) contra la
/// misma impresora térmica POS80-CX, que también tiene interfaz
/// Bluetooth además de USB.
class ImpresoraBluetoothService {
  /// Android 12+ exige pedir estos permisos EN EL MOMENTO (no alcanza
  /// con tenerlos declarados en el manifest) antes de poder ver los
  /// dispositivos Bluetooth emparejados o conectarse a ellos.
  static Future<bool> pedirPermisos() async {
    if (!Platform.isAndroid) return true;
    final resultados = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return resultados.values.every((s) => s.isGranted || s.isLimited);
  }

  /// Dispositivos Bluetooth ya emparejados con este celular/tablet (hay
  /// que emparejar la impresora primero desde la configuración de
  /// Bluetooth de Android, como cualquier otro dispositivo).
  static Future<List<BluetoothInfo>> dispositivosEmparejados() async {
    if (!Platform.isAndroid) return [];
    await pedirPermisos();
    return PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<bool> bluetoothPrendido() => PrintBluetoothThermal.bluetoothEnabled;

  static Future<bool> conectar(String direccionMac) {
    return PrintBluetoothThermal.connect(macPrinterAddress: direccionMac);
  }

  static Future<bool> yaConectado() => PrintBluetoothThermal.connectionStatus;

  /// Manda los bytes ESC/POS ya generados (ver TicketGeneratorService) a
  /// la impresora Bluetooth actualmente conectada.
  static Future<bool> imprimir(List<int> bytes) {
    return PrintBluetoothThermal.writeBytes(bytes);
  }
}
