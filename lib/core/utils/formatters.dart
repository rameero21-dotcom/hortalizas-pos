import 'package:intl/intl.dart';

/// Formateadores de moneda y fecha usados en toda la app.
class Formatters {
  static final NumberFormat _moneda = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'$',
    decimalDigits: 0,
  );

  static String formatearMoneda(num valor) => _moneda.format(valor);

  static String formatearFecha(DateTime fecha) =>
      DateFormat('dd/MM/yyyy').format(fecha);

  static String formatearHora(DateTime fecha) =>
      DateFormat('HH:mm').format(fecha);

  static String formatearFechaHora(DateTime fecha) =>
      DateFormat('dd/MM/yyyy HH:mm').format(fecha);
}
