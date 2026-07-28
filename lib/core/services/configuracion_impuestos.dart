import 'package:shared_preferences/shared_preferences.dart';

/// Tasas de impuestos sobre la venta, iguales para todos los productos
/// (a diferencia del costo, que sí varía por producto). Reflejan cómo
/// se calculaban en la planilla de control diario:
/// IIBB = precio de venta * tasaIIBB
/// TSH  = precio de venta * tasaTSH
///
/// Se guardan localmente (no en Firestore) porque son una configuración
/// del negocio, no un dato por venta.
class ConfiguracionImpuestos {
  static const _claveIIBB = 'tasa_iibb';
  static const _claveTSH = 'tasa_tsh';

  // Valores por defecto tomados de la planilla de control diario.
  static const double _iibbPorDefecto = 0.035; // 3.5%
  static const double _tshPorDefecto = 0.01; // 1%

  static Future<double> obtenerTasaIIBB() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_claveIIBB) ?? _iibbPorDefecto;
  }

  static Future<double> obtenerTasaTSH() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_claveTSH) ?? _tshPorDefecto;
  }

  static Future<void> guardarTasaIIBB(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_claveIIBB, valor);
  }

  static Future<void> guardarTasaTSH(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_claveTSH, valor);
  }
}
