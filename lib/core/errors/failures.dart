/// Representación de errores de negocio (capa domain/data).
abstract class Failure {
  final String mensaje;
  const Failure(this.mensaje);
}

class FailureBaseDatosLocal extends Failure {
  const FailureBaseDatosLocal(super.mensaje);
}

class FailureSincronizacion extends Failure {
  const FailureSincronizacion(super.mensaje);
}

class FailureStockInsuficiente extends Failure {
  const FailureStockInsuficiente(super.mensaje);
}

class FailureAutenticacion extends Failure {
  const FailureAutenticacion(super.mensaje);
}

class FailureValidacion extends Failure {
  const FailureValidacion(super.mensaje);
}

class FailureImpresion extends Failure {
  const FailureImpresion(super.mensaje);
}
