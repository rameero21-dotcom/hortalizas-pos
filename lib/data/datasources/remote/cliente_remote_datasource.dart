import '../../models/cliente_model.dart';
import 'firestore_service.dart';

/// Lectura puntual (no en tiempo real) de todos los clientes desde
/// Firestore, para el refresh manual/automático que refleja clientes
/// cargados desde otro dispositivo.
class ClienteRemoteDatasource {
  final FirestoreService _firestoreService;
  ClienteRemoteDatasource(this._firestoreService);

  Future<List<ClienteModel>> obtenerTodos() async {
    final snap = await _firestoreService.clientes.get();
    return snap.docs
        .map((d) => ClienteModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }
}
