import '../entities/stock.dart';

/// Contrato del repositorio de Stock.
abstract class StockRepository {
  Future<Stock?> obtenerPorProducto(String productoId);
  Future<List<Stock>> obtenerTodos();
  Future<void> descontarPorVenta(String productoId, double cantidad, String usuarioId);
  Future<void> ingresarMercaderia(String productoId, double cantidad, String usuarioId, {String? nota});
  Future<void> ajusteManual(String productoId, double nuevaCantidad, String usuarioId, {String? nota});
  Future<List<MovimientoStock>> obtenerHistorial(String productoId);
  Stream<List<Stock>> observarStockBajo();
}
