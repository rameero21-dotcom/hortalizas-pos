import 'package:intl/intl.dart';

/// Formateadores de moneda y fecha usados en toda la app.
class Formatters {
  static final NumberFormat _moneda = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'$',
    decimalDigits: 0,
  );

  static String formatearMoneda(num valor) => _moneda.format(valor);

  /// Convierte lo que alguien tipeó en un campo de MONTO (plata) a un
  /// número. Como [formatearMoneda] nunca muestra centavos
  /// (`decimalDigits: 0`) y separa los miles con un punto (ej.
  /// "897.000"), acá un "." se interpreta como separador de miles, no
  /// como coma decimal — si se tipeara literal (mismo formato que se
  /// ve en pantalla), antes se interpretaba como decimal y "897.000"
  /// se registraba como $897 en vez de $897.000. Una "," se sigue
  /// aceptando como separador decimal, por si alguien la tipea.
  static double? parsearMonto(String texto) {
    final limpio = texto.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(limpio);
  }

  static String formatearFecha(DateTime fecha) =>
      DateFormat('dd/MM/yyyy').format(fecha);

  static String formatearHora(DateTime fecha) =>
      DateFormat('HH:mm').format(fecha);

  static String formatearFechaHora(DateTime fecha) =>
      DateFormat('dd/MM/yyyy HH:mm').format(fecha);

  /// Muestra una cantidad sin el ".0" innecesario cuando es un número
  /// entero (ej: 3 en vez de 3.0), pero conserva los decimales si la
  /// cantidad realmente los tiene (ej: 2.5 kg).
  static String formatearCantidad(num valor) {
    if (valor == valor.roundToDouble()) {
      return valor.toStringAsFixed(0);
    }
    return valor.toString();
  }
}
