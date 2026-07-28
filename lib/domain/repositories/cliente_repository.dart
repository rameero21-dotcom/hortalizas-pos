import '../entities/cliente.dart';

/// Contrato del repositorio de Clientes, incluyendo cuenta corriente
/// (fiado/deuda) para clientes habituales.
abstract class ClienteRepository {
  Future<List<Cliente>> obtenerTodos();
  Future<Cliente?> obtenerPorId(String id);
  Future<void> crear(Cliente cliente);
  Future<void> actualizar(Cliente cliente);
  Future<void> eliminar(String id);

  /// Registra un cargo (aumenta la deuda) o un pago (la disminuye) en
  /// la cuenta corriente del cliente, y actualiza su saldo.
  Future<void> registrarMovimientoCuenta({
    required String clienteId,
    required TipoMovimientoCuenta tipo,
    required double monto,
    required String detalle,
    required String usuarioId,
  });

  Future<List<MovimientoCuentaCorriente>> obtenerMovimientosCuenta(String clienteId);

  /// Trae todos los clientes desde Firestore y actualiza la caché local
  /// (agrega nuevos, actualiza cambiados, borra los que ya no existen).
  /// Se usa antes de mostrar el selector de cliente en caja, para que un
  /// cliente cargado desde otro dispositivo (Admin) aparezca sin
  /// esperar. Si no hay conexión, no hace nada.
  Future<void> refrescarDesdeRemoto();
}
