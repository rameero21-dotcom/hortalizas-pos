import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kClaveHoraCorte = 'hora_corte_dia_laboral';

/// Maneja el "día laboral" del negocio: en vez de medianoche a
/// medianoche, el día arranca y termina a una hora configurable (por
/// defecto 10:00 AM) — así una venta a la 1am sigue contando como
/// parte del día anterior, en vez de cortarse la caja/historial a la
/// mitad de una jornada que sigue de largo hasta la mañana.
///
/// La hora de corte se guarda en Firestore (un solo documento, igual
/// para todo el negocio) además de una copia local para que funcione
/// sin conexión — así cambiarla desde un dispositivo se refleja en
/// todos los demás, en vez de que cada uno use un valor distinto.
class DiaLaboralService {
  static const int _horaCortePorDefecto = 10;

  static DocumentReference get _docConfig =>
      FirebaseFirestore.instance.collection('configuracion').doc('general');

  static Future<int> obtenerHoraCorte() async {
    // Firestore primero (fuente de verdad compartida entre
    // dispositivos), con un timeout corto para no trabar pantallas
    // que se usan seguido (Arqueo, Estadísticas, Facturación) si no
    // hay señal en ese momento.
    try {
      final doc = await _docConfig.get().timeout(const Duration(seconds: 3));
      final data = doc.data() as Map<String, dynamic>?;
      final valor = data?['horaCorteDiaLaboral'] as int?;
      if (valor != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kClaveHoraCorte, valor);
        return valor;
      }
    } catch (_) {
      // Sin conexión o tardó demasiado: se sigue con la copia local.
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kClaveHoraCorte) ?? _horaCortePorDefecto;
  }

  /// Guarda la hora de corte nueva. Devuelve `true` si se pudo subir a
  /// Firestore (así se sabe si de verdad va a quedar igual en todos los
  /// dispositivos, o si por ahora solo cambió en este); en cualquier
  /// caso queda guardada localmente.
  static Future<bool> guardarHoraCorte(int hora) async {
    final horaClamp = hora.clamp(0, 23);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kClaveHoraCorte, horaClamp);
    try {
      await _docConfig.set({'horaCorteDiaLaboral': horaClamp}, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Devuelve el rango (inicio, fin) del "día laboral" al que pertenece
  /// [momento]. Por ejemplo, con corte a las 10:00: una venta de las
  /// 01:00 del 12/08 pertenece al día laboral que arrancó el 11/08 a
  /// las 10:00 y termina el 12/08 a las 10:00.
  static Future<({DateTime inicio, DateTime fin})> rangoDelDia(DateTime momento) async {
    final horaCorte = await obtenerHoraCorte();
    final diaBase = DateTime(momento.year, momento.month, momento.day, horaCorte);
    final DateTime inicio;
    if (momento.isBefore(diaBase)) {
      // Todavía no llegó la hora de corte de hoy: este momento
      // pertenece al día laboral que arrancó AYER a la hora de corte.
      inicio = diaBase.subtract(const Duration(days: 1));
    } else {
      inicio = diaBase;
    }
    return (inicio: inicio, fin: inicio.add(const Duration(days: 1)));
  }

  /// Atajo para "el día laboral de ahora mismo".
  static Future<({DateTime inicio, DateTime fin})> rangoDeHoy() => rangoDelDia(DateTime.now());
}
