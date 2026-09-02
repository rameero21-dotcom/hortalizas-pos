import '../entities/caja.dart';

/// Contrato del repositorio de Caja: movimientos manuales de efectivo
/// (ingresos/egresos) y cierres/arqueos con conteo de billetes.
abstract class CajaRepository {
  Future<void> registrarMovimiento({
    required TipoMovimientoCaja tipo,
    required double monto,
    required String detalle,
    required String usuarioId,
    MetodoMovimientoCaja metodo = MetodoMovimientoCaja.efectivo,
  });

  Future<List<MovimientoCaja>> obtenerMovimientos(DateTime desde, DateTime hasta);

  /// A diferencia de `obtenerMovimientos` (SQLite de este dispositivo),
  /// trae los movimientos de TODOS los dispositivos vía Firestore. Se
  /// usa en el apartado de "Movimientos de caja" de Historial. Requiere
  /// conexión.
  Future<List<MovimientoCaja>> obtenerMovimientosGlobal(DateTime desde, DateTime hasta);

  /// Elimina un movimiento manual de caja (ingreso/egreso). No aplica a
  /// ventas, que se eliminan con VentaRepository.eliminarVenta.
  Future<void> eliminarMovimiento(String id);

  Future<void> guardarCierre({
    required double cajaInicio,
    required List<ConteoBillete> billetes,
    required String usuarioId,
    String? nota,
  });

  Future<List<CierreCaja>> obtenerCierres(DateTime desde, DateTime hasta);

  /// A diferencia de `obtenerCierres` (SQLite de este dispositivo), trae
  /// los cierres de TODOS los dispositivos vía Firestore. Requiere conexión.
  Future<List<CierreCaja>> obtenerCierresGlobal(DateTime desde, DateTime hasta);
}
