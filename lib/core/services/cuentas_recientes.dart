import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Un usuario que ya inició sesión antes en este dispositivo (para
/// mostrarlo como acceso rápido al elegir con cuál cuenta entrar).
/// Por seguridad NUNCA se guarda la contraseña, solo el email y datos
/// para mostrar en la lista.
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
/// dispositivo, para poder elegir rápido con cuál entrar sin tener que
/// acordarse/escribir el email de cada usuario cada vez.
class CuentasRecientes {
  static const _clave = 'cuentas_recientes';
  static const _maximo = 6;

  static Future<List<CuentaReciente>> obtener() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clave);
    if (raw == null || raw.isEmpty) return [];
    final lista = jsonDecode(raw) as List<dynamic>;
    return lista.map((m) => CuentaReciente.fromMap(m as Map<String, dynamic>)).toList();
  }

  /// Agrega (o actualiza si ya estaba) una cuenta al principio de la
  /// lista, y recorta al máximo de cuentas guardadas.
  static Future<void> agregar(CuentaReciente cuenta) async {
    final actuales = await obtener();
    actuales.removeWhere((c) => c.email == cuenta.email);
    final nuevaLista = [cuenta, ...actuales].take(_maximo).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(nuevaLista.map((c) => c.toMap()).toList()));
  }

  static Future<void> quitar(String email) async {
    final actuales = await obtener();
    actuales.removeWhere((c) => c.email == email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(actuales.map((c) => c.toMap()).toList()));
  }
}
