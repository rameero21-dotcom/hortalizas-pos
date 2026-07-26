import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

/// Wrapper fino sobre Firestore para centralizar referencias a colecciones
/// y exponer operaciones genéricas usadas por SyncService.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get productos => _firestore.collection(AppConstants.colProductos);
  CollectionReference get ventas => _firestore.collection(AppConstants.colVentas);
  CollectionReference get stock => _firestore.collection(AppConstants.colStock);
  CollectionReference get usuarios => _firestore.collection(AppConstants.colUsuarios);
  CollectionReference get clientes => _firestore.collection(AppConstants.colClientes);
  CollectionReference get movimientosStock => _firestore.collection(AppConstants.colMovimientosStock);
  CollectionReference get movimientosCaja => _firestore.collection(AppConstants.colMovimientosCaja);
  CollectionReference get cierresCaja => _firestore.collection(AppConstants.colCierresCaja);

  /// Mapa entidad (nombre usado en sync_queue) -> colección real de Firestore.
  CollectionReference coleccionPara(String entidad) {
    switch (entidad) {
      case AppConstants.colProductos:
        return productos;
      case AppConstants.colVentas:
        return ventas;
      case AppConstants.colStock:
        return stock;
      case AppConstants.colUsuarios:
        return usuarios;
      case AppConstants.colClientes:
        return clientes;
      case AppConstants.colMovimientosStock:
        return movimientosStock;
      case AppConstants.colMovimientosCaja:
        return movimientosCaja;
      case AppConstants.colCierresCaja:
        return cierresCaja;
      default:
        throw ArgumentError('Entidad desconocida para Firestore: $entidad');
    }
  }

  /// Sube (crea o reemplaza) un documento. Usado por SyncService al vaciar
  /// la cola de sincronización local.
  Future<void> subirDocumento(String entidad, String id, Map<String, dynamic> data) {
    return coleccionPara(entidad).doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> eliminarDocumento(String entidad, String id) {
    return coleccionPara(entidad).doc(id).delete();
  }
}
