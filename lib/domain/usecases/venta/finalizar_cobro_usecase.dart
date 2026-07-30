import '../../entities/venta.dart';
import '../../entities/cliente.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/cliente_repository.dart';

/// Caso de uso: la caja cobra una venta pendiente.
/// Descuenta stock automáticamente, marca la venta como cobrada con el
/// (o los) método(s) de pago, y si alguna parte se paga como "cuenta
/// corriente" (fiado), genera el cargo en la cuenta del cliente por esa
/// parte específica (no por el total, si el pago fue dividido).
class FinalizarCobroUseCase {
  final VentaRepository _ventaRepository;
  final StockRepository _stockRepository;
  final ClienteRepository _clienteRepository;

  FinalizarCobroUseCase(this._ventaRepository, this._stockRepository, this._clienteRepository);

  Future<Venta> call(
    Venta venta,
    String cajeroId,
    List<DetallePago> pagos, {
    String? clienteId,
    String? cuitDniComprador,
  }) async {
    // Verificación real contra Firestore (no solo el objeto que ya
    // tenemos en mano): cubre tanto el caso de la venta pendiente vista
    // por el stream normal, como el caso más delicado de la venta
    // reconstruida desde el QR de respaldo, que siempre "cree" estar
    // pendiente porque el QR no sabe si alguien ya la cobró. Si no hay
    // conexión para verificar, se sigue igual (offline-first) — el
    // riesgo de doble cobro queda limitado a ese escenario sin señal.
    final estadoReal = await _ventaRepository.obtenerEstadoActualDesdeRemoto(venta.id);
    if (estadoReal != null && estadoReal.estado == EstadoVenta.cobrada) {
      throw ArgumentError('Esta venta ya fue cobrada antes, no se puede cobrar de nuevo');
    }

    if (pagos.isEmpty) {
      throw ArgumentError('Hay que cargar al menos un método de pago');
    }
    final sumaPagos = pagos.fold<double>(0, (acc, p) => acc + p.monto);
    if ((sumaPagos - venta.total).abs() > 0.5) {
      throw ArgumentError(
          'La suma de los pagos (\$${sumaPagos.toStringAsFixed(0)}) no coincide con el total de la venta (\$${venta.total.toStringAsFixed(0)})');
    }

    final incluyeCuentaCorriente = pagos.any((p) => p.metodo == MetodoPago.cuentaCorriente);
    if (incluyeCuentaCorriente && (clienteId == null || clienteId.isEmpty)) {
      throw ArgumentError('Para cobrar a cuenta corriente hay que elegir un cliente');
    }

    // Para transferencia se necesita el CUIT/DNI de quién compra (para
    // que el contador pueda facturarle), salvo que ya se haya elegido
    // un cliente registrado (que ya tiene ese dato guardado).
    final incluyeTransferencia = pagos.any((p) => p.metodo == MetodoPago.transferencia);
    if (incluyeTransferencia &&
        (clienteId == null || clienteId.isEmpty) &&
        (cuitDniComprador == null || cuitDniComprador.trim().isEmpty)) {
      throw ArgumentError('Para cobrar por transferencia hace falta el CUIT o DNI de quién compra');
    }

    for (final item in venta.detalle) {
      await _stockRepository.descontarPorVenta(item.productoId, item.cantidad, cajeroId);
    }

    // Si se pagó con un solo método, se guarda igual en `metodoPago` para
    // que las estadísticas/historial existentes (que agrupan por ese
    // campo) lo sigan viendo como antes. Si fueron varios, queda null ahí
    // y el detalle completo vive en `pagos`.
    final metodoPrincipal = pagos.length == 1 ? pagos.first.metodo : null;

    // Si se seleccionó un cliente registrado, se usa SU CUIT/DNI (ya
    // cargado en su ficha) en vez de pedirlo de nuevo a mano.
    String? cuitDniFinal = cuitDniComprador;
    if (clienteId != null && clienteId.isNotEmpty) {
      final clientes = await _clienteRepository.obtenerTodos();
      for (final c in clientes) {
        if (c.id == clienteId && c.cuitODni.isNotEmpty) {
          cuitDniFinal = c.cuitODni;
          break;
        }
      }
    }

    final ventaCobrada = venta.copyWith(
      estado: EstadoVenta.cobrada,
      metodoPago: metodoPrincipal,
      cajeroId: cajeroId,
      fechaCobro: DateTime.now(),
      clienteId: clienteId,
      pagos: pagos,
      cuitDniComprador: cuitDniFinal,
    );
    await _ventaRepository.finalizarCobro(ventaCobrada);

    if (incluyeCuentaCorriente) {
      final montoCuentaCorriente = pagos
          .where((p) => p.metodo == MetodoPago.cuentaCorriente)
          .fold<double>(0, (acc, p) => acc + p.monto);
      await _clienteRepository.registrarMovimientoCuenta(
        clienteId: clienteId!,
        tipo: TipoMovimientoCuenta.cargo,
        monto: montoCuentaCorriente,
        detalle: 'Venta #${venta.numero}',
        usuarioId: cajeroId,
      );
    }

    return ventaCobrada;
  }
}
