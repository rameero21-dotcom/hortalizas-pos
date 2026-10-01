/// Arma el link de WhatsApp (wa.me) a partir de un teléfono cargado
/// como texto libre (ej. "02615580173", "261 555-0173", "+54 9 261...").
///
/// Argentina no tiene una regla fija de longitud de código de área (van
/// de 2 a 4 dígitos), así que esta normalización NO intenta adivinar
/// dónde termina el código de área para sacar un eventual "15" de
/// celular viejo — si el teléfono se cargó con ese "15" de más, hay
/// que sacarlo a mano al escribirlo. Lo que sí hace: saca todo lo que
/// no sea dígito, saca el "0" de larga distancia nacional si está al
/// principio, y antepone el prefijo que pide WhatsApp para Argentina
/// (54 9 ...).
class WhatsappHelper {
  static String? normalizarNumero(String telefono) {
    final soloDigitos = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (soloDigitos.isEmpty) return null;

    if (soloDigitos.startsWith('54')) {
      // Ya viene con código de país: solo asegura el "9" de celular
      // que WhatsApp exige para números argentinos.
      if (soloDigitos.length > 2 && soloDigitos[2] == '9') return soloDigitos;
      return '549${soloDigitos.substring(2)}';
    }

    final sinCero = soloDigitos.startsWith('0') ? soloDigitos.substring(1) : soloDigitos;
    return '549$sinCero';
  }

  /// null si el teléfono está vacío o no tiene ningún dígito cargado.
  static Uri? linkChat(String telefono) {
    final numero = normalizarNumero(telefono);
    if (numero == null) return null;
    return Uri.parse('https://wa.me/$numero');
  }
}
