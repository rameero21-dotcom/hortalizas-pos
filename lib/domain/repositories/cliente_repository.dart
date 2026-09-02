import '../entities/cliente.dart';
import '../entities/venta.dart' show MetodoPago;

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
    MetodoPago? metodoPago,
  });

  Future<List<MovimientoCuentaCorriente>> obtenerMovimientosCuenta(String clienteId);

  /// Stream en tiempo real (directo de Firestore) de los movimientos de
  /// un cliente puntual — para que un pago/cargo cargado desde
  /// cualquier dispositivo aparezca acá sin depender de la copia local.
  Stream<List<MovimientoCuentaCorriente>> observarMovimientosDeCliente(String clienteId);

  /// Todos los movimientos de cuenta corriente de TODOS los clientes en
  /// un rango de fechas, sin importar el dispositivo. Se usa en el
  /// reporte exportable en PDF. Requiere conexión.
  Future<List<MovimientoCuentaCorriente>> obtenerMovimientosCuentaGlobal(DateTime desde, DateTime hasta);

  /// Trae todos los clientes desde Firestore y actualiza la caché local
  /// (agrega nuevos, actualiza cambiados, borra los que ya no existen).
  /// Se usa antes de mostrar el selector de cliente en caja, para que un
  /// cliente cargado desde otro dispositivo (Admin) aparezca sin
  /// esperar. Si no hay conexión, no hace nada.
  Future<void> refrescarDesdeRemoto();
}
