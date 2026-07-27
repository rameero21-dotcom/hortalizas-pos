import '../../models/producto_model.dart';
import 'firestore_service.dart';

/// Lectura puntual (no en tiempo real) del catálogo completo de
/// productos desde Firestore. Se usa para el refresh manual: traer lo
/// último que subieron otros dispositivos y actualizar la caché local.
class ProductoRemoteDatasource {
  final FirestoreService _firestoreService;
  ProductoRemoteDatasource(this._firestoreService);

  Future<List<ProductoModel>> obtenerTodos() async {
    final snap = await _firestoreService.productos.get();
    return snap.docs
        .map((d) => ProductoModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }
}
