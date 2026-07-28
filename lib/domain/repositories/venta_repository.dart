import '../entities/venta.dart';

/// Contrato del repositorio de Ventas.
abstract class VentaRepository {
  Future<Venta> crearVenta(Venta venta);
  Future<Venta?> obtenerPorId(String id);
  Future<List<Venta>> obtenerPendientes();
  Future<List<Venta>> obtenerPorRangoFecha(DateTime desde, DateTime hasta);

  /// A diferencia de `obtenerPorRangoFecha` (que consulta el SQLite de
  /// este dispositivo), este trae las ventas de TODO el negocio desde
  /// Firestore, sin importar en qué celular se originaron. Lo usan
  /// Estadísticas e Historial (Fase 4), que necesitan ver el panorama
  /// completo. Requiere conexión.
  Future<List<Venta>> obtenerPorRangoFechaGlobal(DateTime desde, DateTime hasta);
  Future<void> finalizarCobro(Venta venta);
  Stream<List<Venta>> observarPendientes();
  Future<Venta> reconstruirDesdeQr(String qrPayload);

  /// Todas las ventas (boletas) cargadas a un cliente, sin importar en
  /// qué dispositivo se cobraron. Requiere conexión.
  Future<List<Venta>> obtenerPorCliente(String clienteId);

  /// Elimina una venta por completo (ej: se cargó por error). No revierte
  /// el stock automáticamente si ya estaba cobrada; usarlo con cuidado.
  Future<void> eliminarVenta(String id);

  /// Trae el estado ACTUAL de una venta directo desde Firestore (no de
  /// la caché local), para verificar justo antes de cobrar que nadie ya
  /// la haya cobrado antes (ej: el mismo QR de respaldo escaneado dos
  /// veces, o dos cajeros escaneando el mismo QR casi al mismo tiempo).
  /// Si no hay conexión, devuelve null y el llamador debe decidir cómo
  /// proceder (la app sigue funcionando offline, a costa de este chequeo).
  Future<Venta?> obtenerEstadoActualDesdeRemoto(String id);
}
