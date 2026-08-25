import '../../models/stock_model.dart';
import 'firestore_service.dart';

/// Lectura puntual (no en tiempo real) del stock de todos los productos
/// desde Firestore, para el refresh manual.
class StockRemoteDatasource {
  final FirestoreService _firestoreService;
  StockRemoteDatasource(this._firestoreService);

  Future<List<StockModel>> obtenerTodos() async {
    final snap = await _firestoreService.stock.get();
    return snap.docs
        .map((d) => StockModel.fromMap(d.data() as Map<String, dynamic>, idDocumento: d.id))
        .toList();
  }

  /// Stream en tiempo real del stock de todos los productos: cualquier
  /// cambio hecho desde CUALQUIER dispositivo (Windows o Android) llega
  /// acá en segundos, sin necesitar salir y volver a entrar a la
  /// pantalla ni esperar ningún refresh manual.
  Stream<List<StockModel>> observarTodos() {
    return _firestoreService.stock.snapshots().map((snap) => snap.docs
        .map((d) => StockModel.fromMap(d.data() as Map<String, dynamic>, idDocumento: d.id))
        .toList());
  }

  /// Todos los movimientos de stock (ingresos, mermas, ajustes, ventas)
  /// de TODOS los productos, sin importar el dispositivo. Se usa en el
  /// historial de stock. Requiere conexión.
  Future<List<MovimientoStockModel>> obtenerTodosLosMovimientos() async {
    final snap = await _firestoreService.movimientosStock.get();
    final movimientos = snap.docs
        .map((d) => MovimientoStockModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
    movimientos.sort((a, b) => b.fecha.compareTo(a.fecha));
    return movimientos;
  }
}
