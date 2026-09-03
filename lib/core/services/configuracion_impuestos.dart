import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tasas de impuestos sobre la venta, iguales para todos los productos
/// (a diferencia del costo, que sí varía por producto). Reflejan cómo
/// se calculaban en la planilla de control diario:
/// IIBB = precio de venta * tasaIIBB
/// TSH  = precio de venta * tasaTSH
///
/// Se guardan en Firestore (mismo documento de configuración general
/// que la hora de corte del día laboral) además de una copia local
/// para que funcione sin conexión — así cambiarlas desde un
/// dispositivo se refleja en todos los demás.
class ConfiguracionImpuestos {
  static const _claveIIBB = 'tasa_iibb';
  static const _claveTSH = 'tasa_tsh';

  // Valores por defecto tomados de la planilla de control diario.
  static const double _iibbPorDefecto = 0.035; // 3.5%
  static const double _tshPorDefecto = 0.01; // 1%

  static DocumentReference get _docConfig =>
      FirebaseFirestore.instance.collection('configuracion').doc('general');

  static Future<double> obtenerTasaIIBB() async {
    try {
      final doc = await _docConfig.get().timeout(const Duration(seconds: 3));
      final valor = (doc.data() as Map<String, dynamic>?)?['tasaIIBB'] as num?;
      if (valor != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_claveIIBB, valor.toDouble());
        return valor.toDouble();
      }
    } catch (_) {
      // Sin conexión: se sigue con la copia local.
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_claveIIBB) ?? _iibbPorDefecto;
  }

  static Future<double> obtenerTasaTSH() async {
    try {
      final doc = await _docConfig.get().timeout(const Duration(seconds: 3));
      final valor = (doc.data() as Map<String, dynamic>?)?['tasaTSH'] as num?;
      if (valor != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_claveTSH, valor.toDouble());
        return valor.toDouble();
      }
    } catch (_) {
      // Sin conexión: se sigue con la copia local.
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_claveTSH) ?? _tshPorDefecto;
  }

  /// Devuelve `true` si se pudo subir a Firestore.
  static Future<bool> guardarTasaIIBB(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_claveIIBB, valor);
    try {
      await _docConfig.set({'tasaIIBB': valor}, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Devuelve `true` si se pudo subir a Firestore.
  static Future<bool> guardarTasaTSH(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_claveTSH, valor);
    try {
      await _docConfig.set({'tasaTSH': valor}, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }
}
