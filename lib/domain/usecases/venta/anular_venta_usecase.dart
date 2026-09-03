import '../../entities/venta.dart';
import '../../entities/cliente.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/cliente_repository.dart';

/// Caso de uso: anular una venta que ya fue cobrada (por ejemplo, se
/// cargó mal por error). A diferencia de simplemente borrarla, esto:
/// - Devuelve el stock descontado (un ingreso por cada producto vendido).
/// - Si alguna parte se había pagado como cuenta corriente (fiado),
///   registra un pago compensatorio para bajarle la deuda al cliente
///   de vuelta (no le queda debiendo algo que en verdad no compró).
/// - NO borra el registro: lo deja marcado como "cancelada", para que
///   quede el rastro de qué pasó, pero sin contar en ningún total
///   (Historial, Estadísticas, Arqueo de Caja, Facturación ya filtran
///   por estado == cobrada, así que una cancelada desaparece sola de
///   todos esos lados).
class AnularVentaUseCase {
  final VentaRepository _ventaRepository;
  final StockRepository _stockRepository;
  final ClienteRepository _clienteRepository;

  AnularVentaUseCase(this._ventaRepository, this._stockRepository, this._clienteRepository);

  Future<void> call(Venta venta, String usuarioId) async {
    if (venta.estado != EstadoVenta.cobrada) {
      throw ArgumentError('Solo se puede anular una venta que ya fue cobrada.');
    }

    // Chequeo contra el estado REAL en el servidor, no solo el objeto
    // que ya se tenía en mano (que puede estar desactualizado si otro
    // admin la anuló o editó en el momento). Sin esto, dos anulaciones
    // casi simultáneas devolverían el stock DOS VECES.
    final estadoReal = await _ventaRepository.obtenerEstadoActualDesdeRemoto(venta.id);
    if (estadoReal != null && estadoReal.estado != EstadoVenta.cobrada) {
      throw ArgumentError(
          'Esta venta ya no está cobrada (puede que otro usuario la haya anulado o editado recién) — recargá la pantalla.');
    }

    // Devolver el stock de cada producto vendido.
    for (final item in venta.detalle) {
      await _stockRepository.ingresarMercaderia(
        item.productoId,
        item.cantidad,
        usuarioId,
        nota: 'Anulación de venta #${venta.numero}',
      );
    }

    // Si una parte (o todo) se pagó como cuenta corriente, revertir esa
    // deuda con un pago compensatorio.
    final montoFiado = venta.pagos.isNotEmpty
        ? venta.pagos.where((p) => p.metodo == MetodoPago.cuentaCorriente).fold(0.0, (a, p) => a + p.monto)
        : (venta.metodoPago == MetodoPago.cuentaCorriente ? venta.total : 0.0);

    if (montoFiado > 0 && venta.clienteId != null) {
      await _clienteRepository.registrarMovimientoCuenta(
        clienteId: venta.clienteId!,
        tipo: TipoMovimientoCuenta.pago,
        monto: montoFiado,
        detalle: 'Anulación de venta #${venta.numero}',
        usuarioId: usuarioId,
      );
    }

    await _ventaRepository.finalizarCobro(venta.copyWith(estado: EstadoVenta.cancelada));
  }
}
