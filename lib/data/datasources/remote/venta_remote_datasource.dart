import '../../models/venta_model.dart';
import 'firestore_service.dart';

/// Lectura en tiempo real de ventas pendientes desde Firestore.
/// Esta es la vía principal por la que la caja ve las ventas del
/// vendedor (el QR es solo respaldo, ver Fase 3).
class VentaRemoteDatasource {
  final FirestoreService _firestoreService;
  VentaRemoteDatasource(this._firestoreService);

  Stream<List<VentaModel>> observarPendientes() {
    return _firestoreService.ventas
        .where('estado', isEqualTo: 'pendiente')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => VentaModel.fromRemoteMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  /// Trae todas las ventas (de cualquier estado) dentro de un rango de
  /// fechas, sin importar en qué dispositivo se crearon. Se usa para
  /// Estadísticas e Historial (Fase 4), que necesitan ver el negocio
  /// completo y no solo lo que pasó por el SQLite de este celular.
  /// Requiere conexión: a diferencia de la venta/cobro, estas pantallas
  /// son de administración y no tienen fallback offline.
  Future<List<VentaModel>> obtenerPorRangoFecha(DateTime desde, DateTime hasta) async {
    final snap = await _firestoreService.ventas
        .where('fecha', isGreaterThanOrEqualTo: desde.toIso8601String())
        .where('fecha', isLessThanOrEqualTo: hasta.toIso8601String())
        .orderBy('fecha', descending: true)
        .get();
    return snap.docs.map((d) => VentaModel.fromRemoteMap(d.data() as Map<String, dynamic>)).toList();
  }

  /// Todas las boletas (ventas) cargadas a un cliente puntual, sin
  /// importar en qué dispositivo se cobraron. Se usa en la pantalla de
  /// cuenta corriente del cliente, para ver el detalle completo de
  /// productos y cómo se pagó cada una.
  Future<List<VentaModel>> obtenerPorCliente(String clienteId) async {
    final snap = await _firestoreService.ventas.where('clienteId', isEqualTo: clienteId).get();
    final ventas =
        snap.docs.map((d) => VentaModel.fromRemoteMap(d.data() as Map<String, dynamic>)).toList();
    ventas.sort((a, b) => b.fecha.compareTo(a.fecha));
    return ventas;
  }
}
