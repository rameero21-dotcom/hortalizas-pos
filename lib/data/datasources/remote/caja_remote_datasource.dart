import '../../models/caja_model.dart';
import 'firestore_service.dart';

/// Lectura de movimientos de caja (ingresos/egresos manuales) desde
/// Firestore, sin importar en qué dispositivo se cargaron. Se usa para
/// el apartado de "Movimientos de caja" dentro de Historial, que
/// necesita ver el panorama completo del negocio.
class CajaRemoteDatasource {
  final FirestoreService _firestoreService;
  CajaRemoteDatasource(this._firestoreService);

  Future<List<MovimientoCajaModel>> obtenerMovimientosPorRango(DateTime desde, DateTime hasta) async {
    final snap = await _firestoreService.movimientosCaja
        .where('fecha', isGreaterThanOrEqualTo: desde.toIso8601String())
        .where('fecha', isLessThanOrEqualTo: hasta.toIso8601String())
        .get();
    final movimientos =
        snap.docs.map((d) => MovimientoCajaModel.fromMap(d.data() as Map<String, dynamic>)).toList();
    movimientos.sort((a, b) => b.fecha.compareTo(a.fecha));
    return movimientos;
  }
}
