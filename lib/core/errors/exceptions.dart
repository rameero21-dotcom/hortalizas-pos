/// Excepciones técnicas lanzadas por datasources (local/remote).
class ServerException implements Exception {
  final String mensaje;
  ServerException(this.mensaje);
}

class CacheException implements Exception {
  final String mensaje;
  CacheException(this.mensaje);
}

class SyncException implements Exception {
  final String mensaje;
  SyncException(this.mensaje);
}

class PrinterException implements Exception {
  final String mensaje;
  PrinterException(this.mensaje);
}
