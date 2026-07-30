import '../../models/proveedor_model.dart';
import 'firestore_service.dart';

class ProveedorRemoteDatasource {
  final FirestoreService _firestoreService;
  ProveedorRemoteDatasource(this._firestoreService);

  Future<List<ProveedorModel>> obtenerTodos() async {
    final snap = await _firestoreService.proveedores.get();
    return snap.docs
        .map((d) => ProveedorModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  /// Todos los pedidos de TODOS los proveedores, sin importar el
  /// dispositivo (para ver el detalle de un proveedor con datos
  /// cargados desde cualquier celular/PC).
  Future<List<PedidoProveedorModel>> obtenerTodosLosPedidos() async {
    final snap = await _firestoreService.pedidosProveedor.get();
    final pedidos = snap.docs
        .map((d) => PedidoProveedorModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
    pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));
    return pedidos;
  }
}
