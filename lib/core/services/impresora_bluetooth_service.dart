import 'dart:io';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Maneja la impresión por Bluetooth (celular/tablet Android) contra la
/// misma impresora térmica POS80-CX, que también tiene interfaz
/// Bluetooth además de USB.
class ImpresoraBluetoothService {
  /// Dispositivos Bluetooth ya emparejados con este celular/tablet (hay
  /// que emparejar la impresora primero desde la configuración de
  /// Bluetooth de Android, como cualquier otro dispositivo).
  static Future<List<BluetoothInfo>> dispositivosEmparejados() async {
    if (!Platform.isAndroid) return [];
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
