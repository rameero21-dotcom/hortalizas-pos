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

  /// Lee UN documento puntual directo de Firestore (no de un stream ni
  /// caché), para verificar el estado real de una venta antes de
  /// cobrarla (evita doble cobro si el QR se escanea dos veces).
  Future<VentaModel?> obtenerPorIdRemoto(String id) async {
    final doc = await _firestoreService.ventas.doc(id).get();
    if (!doc.exists) return null;
    return VentaModel.fromRemoteMap(doc.data() as Map<String, dynamic>);
  }

  /// El número de venta más alto que existe en TODO el negocio (todos
  /// los dispositivos), no solo en la copia local de este celular.
  /// Se usa como piso al numerar una venta nueva: la numeración
  /// puramente local (MAX+1 de la caché del dispositivo) puede
  /// duplicarse entre dos celulares que vendan casi al mismo tiempo, o
  /// si uno de los dos no sincronizó hace rato. Con conexión, esto
  /// reduce mucho ese riesgo (no lo elimina del todo: dos ventas
  /// simultáneas con conexión, en el instante exacto entre esta
  /// consulta y la siguiente, todavía podrían coincidir — pero es una
  /// ventana mucho más chica que confiar solo en lo local).
  Future<int> obtenerNumeroMaximo() async {
    final snap = await _firestoreService.ventas.orderBy('numero', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return 0;
    final data = snap.docs.first.data() as Map<String, dynamic>;
    return (data['numero'] as num?)?.toInt() ?? 0;
  }
}
