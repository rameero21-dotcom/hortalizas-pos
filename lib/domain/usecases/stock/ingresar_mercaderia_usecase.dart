import '../../repositories/stock_repository.dart';

class IngresarMercaderiaUseCase {
  final StockRepository _stockRepository;
  IngresarMercaderiaUseCase(this._stockRepository);

  Future<void> call(String productoId, double cantidad, String usuarioId, {String? nota}) {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad a ingresar debe ser mayor a cero');
    }
    return _stockRepository.ingresarMercaderia(productoId, cantidad, usuarioId, nota: nota);
  }
}
