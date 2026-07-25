import '../../repositories/stock_repository.dart';

class AjusteManualStockUseCase {
  final StockRepository _stockRepository;
  AjusteManualStockUseCase(this._stockRepository);

  Future<void> call(String productoId, double nuevaCantidad, String usuarioId, {String? nota}) {
    if (nuevaCantidad < 0) {
      throw ArgumentError('El stock no puede ser negativo');
    }
    return _stockRepository.ajusteManual(productoId, nuevaCantidad, usuarioId, nota: nota);
  }
}
