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
        .map((d) => StockModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }
}
