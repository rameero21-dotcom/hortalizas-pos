import '../entities/stock.dart';

/// Contrato del repositorio de Stock.
abstract class StockRepository {
  Future<Stock?> obtenerPorProducto(String productoId);
  Future<List<Stock>> obtenerTodos();
  Future<void> descontarPorVenta(String productoId, double cantidad, String usuarioId);
  Future<void> ingresarMercaderia(String productoId, double cantidad, String usuarioId, {String? nota});
  Future<void> ajusteManual(String productoId, double nuevaCantidad, String usuarioId, {String? nota});
  Future<void> registrarMerma(String productoId, double cantidad, String usuarioId, {String? nota});
  Future<List<MovimientoStock>> obtenerHistorial(String productoId);

  /// Todos los movimientos de stock (ingresos, mermas, ajustes, ventas)
  /// de TODOS los productos, sin importar el dispositivo. Se usa en el
  /// historial de stock. Requiere conexión.
  Future<List<MovimientoStock>> obtenerHistorialGlobal();

  /// Borra un movimiento de stock puntual del historial (no revierte
  /// la cantidad de stock, solo saca el registro del historial).
  Future<void> eliminarMovimiento(String id);

  Stream<List<Stock>> observarStockBajo();

  /// Trae las cantidades de stock desde Firestore y actualiza la caché
  /// local. Ver ProductoRepository.refrescarDesdeRemoto para el mismo
  /// criterio.
  Future<void> refrescarDesdeRemoto();

  /// Stream en tiempo real de todo el stock, directo de Firestore (no
  /// pasa por la caché local): se usa en pantallas donde hace falta ver
  /// los cambios apenas pasan, sin esperar un refresh manual.
  Stream<List<Stock>> observarTodos();
}
