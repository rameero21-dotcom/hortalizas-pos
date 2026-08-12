import 'package:shared_preferences/shared_preferences.dart';

const _kClaveHoraCorte = 'hora_corte_dia_laboral';

/// Maneja el "día laboral" del negocio: en vez de medianoche a
/// medianoche, el día arranca y termina a una hora configurable (por
/// defecto 10:00 AM) — así una venta a la 1am sigue contando como
/// parte del día anterior, en vez de cortarse la caja/historial a la
/// mitad de una jornada que sigue de largo hasta la mañana.
class DiaLaboralService {
  static const int _horaCortePorDefecto = 10;

  static Future<int> obtenerHoraCorte() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kClaveHoraCorte) ?? _horaCortePorDefecto;
  }

  static Future<void> guardarHoraCorte(int hora) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kClaveHoraCorte, hora.clamp(0, 23));
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
