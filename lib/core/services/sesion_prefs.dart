import 'package:shared_preferences/shared_preferences.dart';

/// Guarda si el usuario eligió "mantener la sesión iniciada" al hacer
/// login. Firebase Auth de por sí ya persiste la sesión entre aperturas
/// de la app; esto es lo que decide si, al abrir la app de nuevo, hay
/// que aprovechar esa sesión guardada (entrar directo) o forzar el
/// login de nuevo (por ejemplo, en un dispositivo compartido donde no
/// se quiere dejar la sesión abierta).
class SesionPrefs {
  static const _clave = 'mantener_sesion';

  static Future<bool> obtenerMantenerSesion() async {
    final prefs = await SharedPreferences.getInstance();
    // Por defecto, mantenida (es lo más cómodo para el uso diario).
    return prefs.getBool(_clave) ?? true;
  }

  static Future<void> guardarMantenerSesion(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clave, valor);
  }
}
