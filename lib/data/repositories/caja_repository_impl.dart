import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/sync_service.dart';
import '../../domain/entities/caja.dart';
import '../../domain/repositories/caja_repository.dart';
import '../datasources/local/caja_local_datasource.dart';
import '../datasources/local/sync_queue_local_datasource.dart';
import '../datasources/remote/caja_remote_datasource.dart';
import '../models/caja_model.dart';

class CajaRepositoryImpl implements CajaRepository {
  final CajaLocalDatasource _local;
  final SyncQueueLocalDatasource _syncQueue;
  final CajaRemoteDatasource _remote;
  final SyncService _syncService;
  final _uuid = Uuid();

  CajaRepositoryImpl(this._local, this._syncQueue, this._remote, this._syncService);

  @override
  Future<void> registrarMovimiento({
    required TipoMovimientoCaja tipo,
    required double monto,
    required String detalle,
    required String usuarioId,
    MetodoMovimientoCaja metodo = MetodoMovimientoCaja.efectivo,
  }) async {
    final movimiento = MovimientoCajaModel(
      id: _uuid.v4(),
      tipo: tipo,
      monto: monto,
      detalle: detalle,
      fecha: DateTime.now(),
      usuarioId: usuarioId,
      metodo: metodo,
    );
    await _local.registrarMovimiento(movimiento);
    await _syncQueue.encolar(
      entidad: AppConstants.colMovimientosCaja,
      entidadId: movimiento.id,
      operacion: 'set',
      payload: movimiento.toMap(),
    );
    await _syncService.sincronizarAhora();
  }

  @override
  Future<List<MovimientoCaja>> obtenerMovimientos(DateTime desde, DateTime hasta) =>
      _local.obtenerMovimientos(desde, hasta);

  @override
  Future<List<MovimientoCaja>> obtenerMovimientosGlobal(DateTime desde, DateTime hasta) =>
      _remote.obtenerMovimientosPorRango(desde, hasta);

  @override
  Future<void> eliminarMovimiento(String id) async {
    await _local.eliminarMovimiento(id);
    await _syncQueue.encolar(
      entidad: AppConstants.colMovimientosCaja,
      entidadId: id,
      operacion: 'delete',
      payload: const {},
    );
    await _syncService.sincronizarAhora();
  }

  @override
  Future<void> guardarCierre({
    required double cajaInicio,
    required List<ConteoBillete> billetes,
    required String usuarioId,
    String? nota,
  }) async {
    final cierre = CierreCajaModel(
      id: _uuid.v4(),
      fecha: DateTime.now(),
      cajaInicio: cajaInicio,
      billetes: billetes,
      usuarioId: usuarioId,
      nota: nota,
    );
    await _local.guardarCierre(cierre);
    await _syncQueue.encolar(
      entidad: AppConstants.colCierresCaja,
      entidadId: cierre.id,
      operacion: 'set',
      payload: cierre.toMap(),
    );
    await _syncService.sincronizarAhora();
  }

  @override
  Future<List<CierreCaja>> obtenerCierres(DateTime desde, DateTime hasta) =>
      _local.obtenerCierres(desde, hasta);

  @override
  Future<List<CierreCaja>> obtenerCierresGlobal(DateTime desde, DateTime hasta) =>
      _remote.obtenerCierresPorRango(desde, hasta);
}
