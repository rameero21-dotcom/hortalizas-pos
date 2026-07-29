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
  CollectionReference get movimientosCuentaCorriente =>
      _firestore.collection(AppConstants.colMovimientosCuentaCorriente);

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
      case AppConstants.colMovimientosCuentaCorriente:
        return movimientosCuentaCorriente;
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

  /// Suma (o resta, con delta negativo) un campo numérico de forma
  /// ATÓMICA en el servidor de Firestore — a diferencia de leer el valor
  /// actual y escribir un nuevo total calculado, esto es seguro aunque
  /// dos dispositivos lo hagan sobre el mismo documento casi al mismo
  /// tiempo (ej: dos cajeros descontando stock del mismo producto):
  /// Firestore aplica ambos incrementos sin que ninguno se pierda,
  /// mientras que con un "set" de un total ya calculado, el que
  /// sincroniza último pisaría al otro.
  Future<void> incrementarCampo(String entidad, String id, String campo, num delta) {
    return coleccionPara(entidad).doc(id).set({campo: FieldValue.increment(delta)}, SetOptions(merge: true));
  }

  /// Crea/actualiza una venta SOLO SI todavía no está cobrada en el
  /// servidor. Cubre este caso: el vendedor crea una venta sin señal;
  /// la caja la cobra al toque escaneando el QR de respaldo (con
  /// conexión); recién DESPUÉS el celular del vendedor recupera señal y
  /// sube su "creación" (que en su cabeza todavía está pendiente). Sin
  /// esta protección, esa subida tardía pisaría el estado "cobrada" de
  /// vuelta a "pendiente" con un set/merge común. La transacción lee el
  /// estado actual en el servidor antes de decidir si escribir.
  Future<void> crearVentaSiNoCobrada(String id, Map<String, dynamic> data) {
    final doc = ventas.doc(id);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      if (snapshot.exists && (snapshot.data() as Map<String, dynamic>?)?['estado'] == 'cobrada') {
        return; // ya la cobraron por otro camino; no tocar nada.
      }
      transaction.set(doc, data, SetOptions(merge: true));
    });
  }
}
