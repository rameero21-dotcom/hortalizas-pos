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

  /// Stream en tiempo real de la lista de clientes.
  Stream<List<ClienteModel>> observarTodos() {
    return _firestoreService.clientes.snapshots().map((snap) => snap.docs
        .map((d) => ClienteModel.fromMap(d.data() as Map<String, dynamic>))
        .toList());
  }

  /// Todos los movimientos de cuenta corriente (cargos/pagos) de TODOS
  /// los clientes en un rango de fechas, sin importar en qué dispositivo
  /// se cargaron. Se usa para el reporte exportable en PDF, que necesita
  /// ver el panorama completo del negocio, no solo lo de este celular.
  Future<List<MovimientoCuentaCorrienteModel>> obtenerMovimientosPorRango(
      DateTime desde, DateTime hasta) async {
    final snap = await _firestoreService.movimientosCuentaCorriente
        .where('fecha', isGreaterThanOrEqualTo: desde.toIso8601String())
        .where('fecha', isLessThanOrEqualTo: hasta.toIso8601String())
        .get();
    final movimientos = snap.docs
        .map((d) => MovimientoCuentaCorrienteModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
    movimientos.sort((a, b) => a.fecha.compareTo(b.fecha));
    return movimientos;
  }

  /// Stream en tiempo real de los movimientos de cuenta corriente de UN
  /// cliente puntual — para la pestaña "Pagos y cargos" de su detalle.
  /// Antes esa pestaña solo leía la copia local del dispositivo, así
  /// que un pago cargado desde otro celular/PC (u otro cajero) nunca
  /// aparecía ahí, aunque el saldo del cliente sí se actualizara bien
  /// (eso sincroniza aparte, en el propio documento del cliente).
  Stream<List<MovimientoCuentaCorrienteModel>> observarMovimientosDeCliente(String clienteId) {
    return _firestoreService.movimientosCuentaCorriente
        .where('clienteId', isEqualTo: clienteId)
        .snapshots()
        .map((snap) {
      final movimientos = snap.docs
          .map((d) => MovimientoCuentaCorrienteModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
      movimientos.sort((a, b) => b.fecha.compareTo(a.fecha));
      return movimientos;
    });
  }
}
