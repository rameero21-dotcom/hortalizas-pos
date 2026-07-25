/// Validadores de formularios reutilizables.
class Validators {
  static String? requerido(String? valor, {String campo = 'Este campo'}) {
    if (valor == null || valor.trim().isEmpty) {
      return '$campo es obligatorio';
    }
    return null;
  }

  static String? numeroPositivo(String? valor, {String campo = 'El valor'}) {
    if (valor == null || valor.trim().isEmpty) return '$campo es obligatorio';
    final n = num.tryParse(valor.replaceAll(',', '.'));
    if (n == null) return '$campo debe ser un número';
    if (n <= 0) return '$campo debe ser mayor a cero';
    return null;
  }
}
