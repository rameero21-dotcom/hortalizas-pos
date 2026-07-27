import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Un usuario que ya inició sesión antes en este dispositivo (para
/// mostrarlo como acceso rápido al elegir con cuál cuenta entrar).
class CuentaReciente {
  final String email;
  final String nombre;
  final String rol;

  const CuentaReciente({required this.email, required this.nombre, required this.rol});

  Map<String, dynamic> toMap() => {'email': email, 'nombre': nombre, 'rol': rol};

  factory CuentaReciente.fromMap(Map<String, dynamic> map) => CuentaReciente(
        email: map['email'] as String,
        nombre: map['nombre'] as String,
        rol: map['rol'] as String,
      );
}

/// Guarda la lista de las últimas cuentas que iniciaron sesión en este
/// dispositivo, para poder elegir rápido con cuál entrar. Los datos que
/// se muestran en pantalla (email, nombre, rol) van en SharedPreferences
/// (texto plano, no sensibles). La contraseña, en cambio, se guarda por
/// separado en flutter_secure_storage: en Android usa el Keystore del
/// sistema (cifrado a nivel de hardware), y en Windows el almacén de
/// credenciales de Windows — nunca queda como texto plano en el
/// dispositivo. Esto permite "cambiar de usuario" con un solo toque,
/// sin volver a escribir la contraseña cada vez.
class CuentasRecientes {
  static const _clave = 'cuentas_recientes';
  static const _maximo = 6;
  static const _storage = FlutterSecureStorage();

  static String _clavePassword(String email) => 'password_$email';

  static Future<List<CuentaReciente>> obtener() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clave);
    if (raw == null || raw.isEmpty) return [];
    final lista = jsonDecode(raw) as List<dynamic>;
    return lista.map((m) => CuentaReciente.fromMap(m as Map<String, dynamic>)).toList();
  }

  /// Agrega (o actualiza) una cuenta al principio de la lista, y guarda
  /// su contraseña cifrada para el cambio rápido de usuario.
  static Future<void> agregar(CuentaReciente cuenta, String password) async {
    final actuales = await obtener();
    actuales.removeWhere((c) => c.email == cuenta.email);
    final nuevaLista = [cuenta, ...actuales].take(_maximo).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(nuevaLista.map((c) => c.toMap()).toList()));
    await _storage.write(key: _clavePassword(cuenta.email), value: password);
  }

  /// Devuelve la contraseña guardada para ese email, o null si no hay
  /// ninguna (por ejemplo, si nunca se guardó o el usuario la quitó).
  static Future<String?> obtenerPassword(String email) {
    return _storage.read(key: _clavePassword(email));
  }

  static Future<void> quitar(String email) async {
    final actuales = await obtener();
    actuales.removeWhere((c) => c.email == email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(actuales.map((c) => c.toMap()).toList()));
    await _storage.delete(key: _clavePassword(email));
  }
}
