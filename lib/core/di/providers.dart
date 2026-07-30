import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/database_helper.dart';
import '../../data/datasources/local/producto_local_datasource.dart';
import '../../data/datasources/local/venta_local_datasource.dart';
import '../../data/datasources/local/stock_local_datasource.dart';
import '../../data/datasources/local/usuario_local_datasource.dart';
import '../../data/datasources/local/cliente_local_datasource.dart';
import '../../data/datasources/remote/cliente_remote_datasource.dart';
import '../../data/datasources/local/proveedor_local_datasource.dart';
import '../../data/datasources/remote/proveedor_remote_datasource.dart';
import '../../data/datasources/local/caja_local_datasource.dart';
import '../../data/datasources/remote/caja_remote_datasource.dart';
import '../../data/datasources/local/sync_queue_local_datasource.dart';

import '../../data/datasources/remote/firestore_service.dart';
import '../../data/datasources/remote/auth_service.dart';
import '../../data/datasources/remote/venta_remote_datasource.dart';
import '../../data/datasources/remote/producto_remote_datasource.dart';
import '../../data/datasources/remote/stock_remote_datasource.dart';

import '../../data/repositories/producto_repository_impl.dart';
import '../../data/repositories/venta_repository_impl.dart';
import '../../data/repositories/stock_repository_impl.dart';
import '../../data/repositories/usuario_repository_impl.dart';
import '../../data/repositories/cliente_repository_impl.dart';
import '../../data/repositories/proveedor_repository_impl.dart';
import '../../data/repositories/caja_repository_impl.dart';

import '../../domain/repositories/producto_repository.dart';
import '../../domain/repositories/venta_repository.dart';
import '../../domain/repositories/stock_repository.dart';
import '../../domain/repositories/usuario_repository.dart';
import '../../domain/repositories/cliente_repository.dart';
import '../../domain/repositories/proveedor_repository.dart';
import '../../domain/repositories/caja_repository.dart';

import '../../domain/usecases/venta/crear_venta_usecase.dart';
import '../../domain/usecases/venta/finalizar_cobro_usecase.dart';
import '../../domain/usecases/venta/reconstruir_venta_qr_usecase.dart';
import '../../domain/usecases/estadisticas/obtener_estadisticas_usecase.dart';
import '../../domain/usecases/stock/ingresar_mercaderia_usecase.dart';
import '../../domain/usecases/stock/ajuste_manual_stock_usecase.dart';
import '../../domain/usecases/productos/gestionar_productos_usecase.dart';
import '../../domain/usecases/clientes/gestionar_clientes_usecase.dart';
import '../../domain/usecases/usuarios/login_usecase.dart';

import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/qr_service.dart';
import '../services/reporte_pdf_service.dart';
import '../services/print_service.dart';

/// ================= USUARIO ACTUAL (PLACEHOLDER hasta Fase 2 completa en UI) =================
/// Se sigue usando como fallback rápido para pantallas que todavía no leen
/// del login real (ver AuthGate en main.dart para el flujo con Firebase Auth).
final usuarioActualIdProvider = StateProvider<String>((ref) => 'demo-vendedor');

/// Id del usuario realmente logueado con Firebase Auth (uid), o el
/// placeholder de arriba si por algún motivo no hay sesión (ej. abriendo
/// una pantalla directo en desarrollo, antes de loguearse).
///
/// IMPORTANTE: usa `authStateProvider` (un StreamProvider) en vez de leer
/// `authServiceProvider.usuarioActual` directamente, porque un `Provider`
/// normal cachea su valor la primera vez que se calcula y NO se vuelve a
/// evaluar solo. Si leyera `.usuarioActual` en un Provider común, quedaría
/// pegado al valor que había *antes* del login (probablemente null) para
/// siempre. Al depender de un stream, se recalcula cada vez que cambia el
/// estado de autenticación.
final authStateProvider = StreamProvider((ref) => ref.watch(authServiceProvider).onAuthStateChanged);

final currentUserIdProvider = Provider<String>((ref) {
  ref.watch(authStateProvider); // fuerza reevaluar este provider en cada cambio de sesión
  final uid = ref.watch(authServiceProvider).usuarioActual?.uid; // valor sincrónico siempre fresco
  return uid ?? ref.watch(usuarioActualIdProvider);
});

/// ================= INFRAESTRUCTURA =================
final databaseHelperProvider = Provider((ref) => DatabaseHelper.instance);

final connectivityServiceProvider = Provider((ref) => ConnectivityService());
final qrServiceProvider = Provider((ref) => QrService());
final reportePdfServiceProvider = Provider((ref) => ReportePdfService());
final printServiceProvider = Provider((ref) => PrintService(ref.watch(qrServiceProvider)));

/// ================= FIREBASE =================
final firestoreServiceProvider = Provider((ref) => FirestoreService());
final authServiceProvider = Provider((ref) => AuthService());
final ventaRemoteDsProvider =
    Provider((ref) => VentaRemoteDatasource(ref.watch(firestoreServiceProvider)));
final productoRemoteDsProvider =
    Provider((ref) => ProductoRemoteDatasource(ref.watch(firestoreServiceProvider)));
final stockRemoteDsProvider =
    Provider((ref) => StockRemoteDatasource(ref.watch(firestoreServiceProvider)));

/// ================= DATASOURCES LOCALES =================
final productoLocalDsProvider =
    Provider((ref) => ProductoLocalDatasource(ref.watch(databaseHelperProvider)));
final ventaLocalDsProvider =
    Provider((ref) => VentaLocalDatasource(ref.watch(databaseHelperProvider)));
final stockLocalDsProvider =
    Provider((ref) => StockLocalDatasource(ref.watch(databaseHelperProvider)));
final usuarioLocalDsProvider =
    Provider((ref) => UsuarioLocalDatasource(ref.watch(databaseHelperProvider)));
final clienteLocalDsProvider =
    Provider((ref) => ClienteLocalDatasource(ref.watch(databaseHelperProvider)));
final clienteRemoteDsProvider =
    Provider((ref) => ClienteRemoteDatasource(ref.watch(firestoreServiceProvider)));
final proveedorLocalDsProvider =
    Provider((ref) => ProveedorLocalDatasource(ref.watch(databaseHelperProvider)));
final proveedorRemoteDsProvider =
    Provider((ref) => ProveedorRemoteDatasource(ref.watch(firestoreServiceProvider)));
final cajaLocalDsProvider =
    Provider((ref) => CajaLocalDatasource(ref.watch(databaseHelperProvider)));
final cajaRemoteDsProvider =
    Provider((ref) => CajaRemoteDatasource(ref.watch(firestoreServiceProvider)));
final syncQueueLocalDsProvider =
    Provider((ref) => SyncQueueLocalDatasource(ref.watch(databaseHelperProvider)));

/// ================= SYNC SERVICE (depende de datasources) =================
final syncServiceProvider = Provider((ref) => SyncService(
      ref.watch(syncQueueLocalDsProvider),
      ref.watch(firestoreServiceProvider),
      ref.watch(connectivityServiceProvider),
    ));

/// ================= REPOSITORIOS =================
final productoRepositoryProvider = Provider<ProductoRepository>((ref) => ProductoRepositoryImpl(
      ref.watch(productoLocalDsProvider),
      ref.watch(syncQueueLocalDsProvider),
      ref.watch(productoRemoteDsProvider),
      ref.watch(syncServiceProvider),
    ));
final ventaRepositoryProvider = Provider<VentaRepository>((ref) => VentaRepositoryImpl(
      ref.watch(ventaLocalDsProvider),
      ref.watch(syncQueueLocalDsProvider),
      ref.watch(qrServiceProvider),
      ref.watch(ventaRemoteDsProvider),
      ref.watch(syncServiceProvider),
    ));
final stockRepositoryProvider = Provider<StockRepository>((ref) => StockRepositoryImpl(
      ref.watch(stockLocalDsProvider),
      ref.watch(syncQueueLocalDsProvider),
      ref.watch(stockRemoteDsProvider),
      ref.watch(syncServiceProvider),
    ));
final usuarioRepositoryProvider = Provider<UsuarioRepository>((ref) => UsuarioRepositoryImpl(
      ref.watch(usuarioLocalDsProvider),
      ref.watch(authServiceProvider),
      ref.watch(firestoreServiceProvider),
    ));
final clienteRepositoryProvider = Provider<ClienteRepository>((ref) => ClienteRepositoryImpl(
      ref.watch(clienteLocalDsProvider),
      ref.watch(syncQueueLocalDsProvider),
      ref.watch(clienteRemoteDsProvider),
      ref.watch(syncServiceProvider),
    ));
final proveedorRepositoryProvider = Provider<ProveedorRepository>((ref) => ProveedorRepositoryImpl(
      ref.watch(proveedorLocalDsProvider),
      ref.watch(syncQueueLocalDsProvider),
      ref.watch(proveedorRemoteDsProvider),
      ref.watch(syncServiceProvider),
    ));
final cajaRepositoryProvider = Provider<CajaRepository>((ref) => CajaRepositoryImpl(
      ref.watch(cajaLocalDsProvider),
      ref.watch(syncQueueLocalDsProvider),
      ref.watch(cajaRemoteDsProvider),
      ref.watch(syncServiceProvider),
    ));

/// ================= CASOS DE USO =================
final crearVentaUseCaseProvider =
    Provider((ref) => CrearVentaUseCase(ref.watch(ventaRepositoryProvider)));
final finalizarCobroUseCaseProvider = Provider((ref) => FinalizarCobroUseCase(
    ref.watch(ventaRepositoryProvider), ref.watch(stockRepositoryProvider), ref.watch(clienteRepositoryProvider)));
final reconstruirVentaQrUseCaseProvider =
    Provider((ref) => ReconstruirVentaQrUseCase(ref.watch(ventaRepositoryProvider)));
final obtenerEstadisticasUseCaseProvider = Provider((ref) => ObtenerEstadisticasUseCase(
    ref.watch(ventaRepositoryProvider), ref.watch(productoRepositoryProvider)));
final ingresarMercaderiaUseCaseProvider =
    Provider((ref) => IngresarMercaderiaUseCase(ref.watch(stockRepositoryProvider)));
final ajusteManualStockUseCaseProvider =
    Provider((ref) => AjusteManualStockUseCase(ref.watch(stockRepositoryProvider)));
final gestionarProductosUseCaseProvider =
    Provider((ref) => GestionarProductosUseCase(ref.watch(productoRepositoryProvider)));
final gestionarClientesUseCaseProvider =
    Provider((ref) => GestionarClientesUseCase(ref.watch(clienteRepositoryProvider)));
final loginUseCaseProvider =
    Provider((ref) => LoginUseCase(ref.watch(usuarioRepositoryProvider)));
