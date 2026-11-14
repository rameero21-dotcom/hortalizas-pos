import 'dart:io';

/// Registro de diagnóstico a disco, pensado para los casos en los que
/// la app se cierra o se traba sin mostrar ningún mensaje de error (en
/// Windows, sobre todo): como no hay ningún aviso en pantalla para
/// mandar por foto, este archivo deja un rastro de hasta dónde llegó a
/// arrancar la app antes de que pase lo que haya pasado.
///
/// Se guarda en una carpeta fija y predecible (no depende de ningún
/// plugin de Flutter, así que funciona desde la primerísima línea de
/// main(), incluso si algo más adelante falla antes de terminar de
/// inicializar) — en Windows, dentro de %APPDATA%\HortalizasPOS.
///
/// Cada línea queda con fecha y hora, para poder ver exactamente en
/// qué paso se cortó la secuencia de arranque la última vez.
class LogService {
  static File? _archivo;
  static bool _advertenciaYaMostrada = false;

  static File? _archivoLog() {
    if (_archivo != null) return _archivo;
    try {
      Directory? base;
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null) base = Directory(appData);
      } else if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) base = Directory(home);
      }
      base ??= Directory.systemTemp;

      final carpeta = Directory('${base.path}${Platform.pathSeparator}HortalizasPOS');
      if (!carpeta.existsSync()) carpeta.createSync(recursive: true);
      _archivo = File('${carpeta.path}${Platform.pathSeparator}registro.txt');
      return _archivo;
    } catch (_) {
      // Si ni siquiera esto funciona, mejor seguir sin loguear que
      // romper el arranque de la app por un problema del propio log.
      if (!_advertenciaYaMostrada) {
        _advertenciaYaMostrada = true;
        stderr.writeln('LogService: no se pudo crear el archivo de registro.');
      }
      return null;
    }
  }

  /// Ruta del archivo de registro, para mostrarla en la pantalla de
  /// Diagnóstico (o para que alguien lo busque a mano en Windows
  /// Explorer si la app no llega a abrir ninguna pantalla).
  static String? ruta() => _archivoLog()?.path;

  /// Agrega una línea con fecha y hora. Nunca tira una excepción: un
  /// fallo acá no debe tirar abajo lo que se estaba por hacer.
  static void registrar(String mensaje) {
    final archivo = _archivoLog();
    if (archivo == null) return;
    try {
      final linea = '${DateTime.now().toIso8601String()}  $mensaje\n';
      archivo.writeAsStringSync(linea, mode: FileMode.append, flush: true);
      _recortarSiHaceFalta(archivo);
    } catch (_) {
      // Mejor esfuerzo: si falla escribir el log, se sigue sin loguear.
    }
  }

  /// Evita que el archivo crezca sin límite con el uso del día a día:
  /// si supera ~300 KB, se queda solo con las últimas ~1000 líneas.
  static void _recortarSiHaceFalta(File archivo) {
    try {
      if (archivo.lengthSync() <= 300 * 1024) return;
      final lineas = archivo.readAsLinesSync();
      if (lineas.length <= 1000) return;
      final ultimas = lineas.sublist(lineas.length - 1000);
      archivo.writeAsStringSync('${ultimas.join('\n')}\n');
    } catch (_) {
      // No es grave si esto falla: en el peor caso el archivo sigue
      // creciendo, pero no se pierde nada que ya estaba guardado.
    }
  }

  /// Contenido completo actual, para mostrarlo en la pantalla de
  /// Diagnóstico. Devuelve texto vacío si todavía no hay nada guardado.
  static String leerContenido() {
    final archivo = _archivoLog();
    if (archivo == null || !archivo.existsSync()) return '';
    try {
      return archivo.readAsStringSync();
    } catch (e) {
      return 'No se pudo leer el archivo de registro: $e';
    }
  }

  static void borrar() {
    final archivo = _archivoLog();
    try {
      if (archivo != null && archivo.existsSync()) archivo.writeAsStringSync('');
    } catch (_) {}
  }
}
