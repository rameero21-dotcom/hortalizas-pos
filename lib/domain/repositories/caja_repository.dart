import '../entities/caja.dart';

/// Contrato del repositorio de Caja: movimientos manuales de efectivo
/// (ingresos/egresos) y cierres/arqueos con conteo de billetes.
abstract class CajaRepository {
  Future<void> registrarMovimiento({
    required TipoMovimientoCaja tipo,
    required double monto,
    required String detalle,
    required String usuarioId,
  });

  Future<List<MovimientoCaja>> obtenerMovimientos(DateTime desde, DateTime hasta);

  Future<void> guardarCierre({
    required double cajaInicio,
    required List<ConteoBillete> billetes,
    required String usuarioId,
    String? nota,
  });

  Future<List<CierreCaja>> obtenerCierres(DateTime desde, DateTime hasta);
}
