import 'package:shared_preferences/shared_preferences.dart';

/// Si el usuario eligió modo oscuro, persistido entre aperturas de la
/// app. Por defecto claro: es el tema "premium" (marfil, tinta,
/// Fraunces) pensado como principal — ver app_theme.dart.
class ThemePrefs {
  static const _clave = 'modo_oscuro';

  static Future<bool> obtenerModoOscuro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_clave) ?? false;
  }

  static Future<void> guardarModoOscuro(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clave, valor);
  }
}
