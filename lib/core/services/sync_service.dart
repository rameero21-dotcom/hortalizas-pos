import 'dart:async';
import '../../data/datasources/local/sync_queue_local_datasource.dart';
import '../../data/datasources/remote/firestore_service.dart';
import 'connectivity_service.dart';

/// Servicio central de sincronización SQLite -> Firestore.
///
/// Estrategia (Fase 2): "cola de salida" simple.
/// - Cada vez que se escribe algo en SQLite (crear producto, crear venta,
///   cobrar, mover stock, etc.) el repositorio correspondiente encola el
///   cambio en `sync_queue` (ver SyncQueueLocalDatasource).
/// - Este servicio vacía esa cola hacia Firestore apenas hay conexión,
///   y también al arrancar la app.
/// - La lectura en tiempo real (ej. la caja viendo ventas pendientes)
///   se hace directo contra streams de Firestore desde la UI
///   (ver CajaHomeScreen), no hace falta bajarlos a SQLite para esta fase.
///
/// Resolución de conflictos: al ser "solo salida" en esta fase no hay
/// conflictos de escritura concurrente sobre el mismo documento; el único
/// caso es reintentar subidas fallidas, lo cual es seguro porque cada
/// subida es un `set` idempotente (mismo id = mismo documento).
class SyncService {
  final SyncQueueLocalDatasource _syncQueue;
  final FirestoreService _firestoreService;
  final ConnectivityService _connectivityService;

  StreamSubscription<bool>? _conexionSub;
  bool _sincronizando = false;

  SyncService(this._syncQueue, this._firestoreService, this._connectivityService);

  /// Se llama una vez al arrancar la app (main.dart): sincroniza si hay
  /// conexión ahora, y se suscribe para sincronizar automáticamente cada
  /// vez que vuelva la conexión.
  Future<void> iniciar() async {
    if (await _connectivityService.hayConexion()) {
      unawaited(sincronizarAhora());
    }
    _conexionSub ??= _connectivityService.onConnectivityChanged.listen((hayConexion) {
      if (hayConexion) unawaited(sincronizarAhora());
    });
  }

  void detener() {
    _conexionSub?.cancel();
    _conexionSub = null;
  }

  /// Procesa toda la cola de cambios pendientes, subiéndolos a Firestore
  /// uno por uno. Si un ítem falla (ej. se corta la conexión a mitad de
  /// camino) se incrementa su contador de intentos y se sigue con el
  /// resto; ese ítem se reintentará en la próxima corrida.
  Future<void> sincronizarAhora() async {
    if (_sincronizando) return; // evita corridas superpuestas
    _sincronizando = true;
    try {
      final pendientes = await _syncQueue.obtenerPendientes();
      for (final item in pendientes) {
        try {
          if (item.operacion == 'delete') {
            await _firestoreService.eliminarDocumento(item.entidad, item.entidadId);
          } else if (item.operacion == 'incrementar') {
            await _firestoreService.incrementarCampo(
              item.entidad,
              item.entidadId,
              item.payload['campo'] as String,
              item.payload['delta'] as num,
            );
          } else if (item.operacion == 'crear_venta_segura') {
            await _firestoreService.crearVentaSiNoCobrada(item.entidadId, item.payload);
          } else {
            await _firestoreService.subirDocumento(item.entidad, item.entidadId, item.payload);
          }
          await _syncQueue.eliminar(item.id);
        } catch (_) {
          await _syncQueue.incrementarIntentos(item.id);
          // Se continúa con el resto de la cola; este ítem se reintenta después.
        }
      }
    } finally {
      _sincronizando = false;
    }
  }
}
