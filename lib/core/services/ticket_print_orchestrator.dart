import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/venta.dart';
import 'impresora_ticket_service.dart';
import 'impresora_bluetooth_service.dart';
import 'ticket_generator_service.dart';

const _kClaveImpresoraWindows = 'nombre_impresora_ticket';
const _kClaveImpresoraBluetoothMac = 'mac_impresora_bluetooth';

/// Guarda/lee qué impresora usa cada plataforma: nombre de impresora de
/// Windows (USB, cable) o dirección MAC Bluetooth (Android/tablet).
class ConfigImpresora {
  static Future<String?> obtenerNombreGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kClaveImpresoraWindows);
  }

  static Future<void> guardarNombre(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClaveImpresoraWindows, nombre);
  }

  static Future<String?> obtenerMacBluetoothGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kClaveImpresoraBluetoothMac);
  }

  static Future<void> guardarMacBluetooth(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClaveImpresoraBluetoothMac, mac);
  }
}

/// Punto único para imprimir el ticket de una venta: arma las 3 copias
/// (la primera con el QR, las otras dos solo con el detalle) y las manda
/// por el camino que corresponda según el dispositivo:
/// - Windows: por USB (cable), a la cola de impresión configurada.
/// - Android (celular o tablet): por Bluetooth, a la impresora emparejada.
///
/// Es "mejor esfuerzo": si la impresora no está configurada, apagada, o
/// falla la conexión, no tira una excepción hacia arriba — la venta ya
/// se guardó bien, lo único que puede fallar es el papel.
class TicketPrintOrchestrator {
  static Future<bool> imprimirTicketVenta(Venta venta) async {
    try {
      if (Platform.isWindows) {
        return await _imprimirEnWindows(venta);
      } else if (Platform.isAndroid) {
        return await _imprimirEnAndroid(venta);
      }
      return false; // Otras plataformas (iOS, etc.) todavía no soportadas.
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _imprimirEnWindows(Venta venta) async {
    final nombreImpresora = await ConfigImpresora.obtenerNombreGuardado();
    if (nombreImpresora == null) return false;

    var huboExito = true;
    for (var copia = 0; copia < 3; copia++) {
      final bytes = await TicketGeneratorService.generarTicketVenta(venta, incluirQr: copia == 0);
      final ok = ImpresoraTicketService.imprimirRaw(nombreImpresora, bytes);
      huboExito = huboExito && ok;
    }
    return huboExito;
  }

  static Future<bool> _imprimirEnAndroid(Venta venta) async {
    final mac = await ConfigImpresora.obtenerMacBluetoothGuardada();
    if (mac == null) return false;

    final yaConectado = await ImpresoraBluetoothService.yaConectado();
    if (!yaConectado) {
      final conectado = await ImpresoraBluetoothService.conectar(mac);
      if (!conectado) return false;
    }

    var huboExito = true;
    for (var copia = 0; copia < 3; copia++) {
      final bytes = await TicketGeneratorService.generarTicketVenta(venta, incluirQr: copia == 0);
      final ok = await ImpresoraBluetoothService.imprimir(bytes);
      huboExito = huboExito && ok;
    }
    return huboExito;
  }
}
