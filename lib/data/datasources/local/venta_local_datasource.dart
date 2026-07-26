import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/detalle_venta.dart';
import '../../../domain/entities/venta.dart';
import '../../models/venta_model.dart';
import 'database_helper.dart';

/// Acceso a ventas (y su detalle) en SQLite.
class VentaLocalDatasource {
  final DatabaseHelper _dbHelper;
  VentaLocalDatasource(this._dbHelper);

  /// Crea la venta dentro de una transacción, asignando el número
  /// correlativo automáticamente (MAX(numero) + 1) para evitar
  /// depender de conexión a Firebase en esta fase.
  Future<VentaModel> crear(VentaModel venta) async {
    final db = await _dbHelper.database;
    late VentaModel ventaConNumero;

    await db.transaction((txn) async {
      final resultado = await txn.rawQuery(
        'SELECT COALESCE(MAX(numero), 0) + 1 AS proximoNumero FROM ${AppConstants.tablaVentas}',
      );
      final numero = resultado.first['proximoNumero'] as int;

      ventaConNumero = VentaModel(
        id: venta.id,
        numero: numero,
        fecha: venta.fecha,
        vendedorId: venta.vendedorId,
        detalle: venta.detalle,
        total: venta.total,
        estado: venta.estado,
      );

      await txn.insert(AppConstants.tablaVentas, ventaConNumero.toMap());
      for (final item in venta.detalle) {
        await txn.insert(AppConstants.tablaDetalleVenta, {
          'ventaId': venta.id,
          'productoId': item.productoId,
          'nombreProducto': item.nombreProducto,
          'cantidad': item.cantidad,
          'precioTotal': item.precioTotal,
        });
      }
    });

    // El encolado a sync_queue lo hace VentaRepositoryImpl (capa de arriba),
    // que sí conoce el id definitivo con el número ya asignado.
    return ventaConNumero;
  }

  Future<List<DetalleVenta>> _obtenerDetalle(String ventaId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      AppConstants.tablaDetalleVenta,
      where: 'ventaId = ?',
      whereArgs: [ventaId],
    );
    return rows
        .map((r) => DetalleVenta(
              productoId: r['productoId'] as String,
              nombreProducto: r['nombreProducto'] as String,
              cantidad: (r['cantidad'] as num).toDouble(),
              precioTotal: (r['precioTotal'] as num).toDouble(),
            ))
        .toList();
  }

  Future<VentaModel?> obtenerPorId(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(AppConstants.tablaVentas, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final detalle = await _obtenerDetalle(id);
    return VentaModel.fromMap(rows.first, detalle);
  }

  Future<List<VentaModel>> obtenerPendientes() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      AppConstants.tablaVentas,
      where: "estado = 'pendiente'",
      orderBy: 'fecha DESC',
    );
    final ventas = <VentaModel>[];
    for (final row in rows) {
      final detalle = await _obtenerDetalle(row['id'] as String);
      ventas.add(VentaModel.fromMap(row, detalle));
    }
    return ventas;
  }

  Future<List<VentaModel>> obtenerPorRangoFecha(DateTime desde, DateTime hasta) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      AppConstants.tablaVentas,
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [desde.toIso8601String(), hasta.toIso8601String()],
      orderBy: 'fecha DESC',
    );
    final ventas = <VentaModel>[];
    for (final row in rows) {
      final detalle = await _obtenerDetalle(row['id'] as String);
      ventas.add(VentaModel.fromMap(row, detalle));
    }
    return ventas;
  }

  /// Guarda (o reemplaza) una venta completa con todo su detalle.
  /// Se usa para el caso QR: una venta que la caja nunca tuvo en su
  /// propio SQLite (se creó en el celular del vendedor) y que hay que
  /// persistir localmente al cobrarla, no solo actualizar un estado.
  Future<void> guardarCompleta(VentaModel venta) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        AppConstants.tablaVentas,
        venta.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(AppConstants.tablaDetalleVenta, where: 'ventaId = ?', whereArgs: [venta.id]);
      for (final item in venta.detalle) {
        await txn.insert(AppConstants.tablaDetalleVenta, {
          'ventaId': venta.id,
          'productoId': item.productoId,
          'nombreProducto': item.nombreProducto,
          'cantidad': item.cantidad,
          'precioTotal': item.precioTotal,
        });
      }
    });
  }

  /// Marca una venta como cobrada: método de pago, cajero y fecha de cobro.
  Future<void> actualizarEstadoCobro(Venta venta) async {
    final db = await _dbHelper.database;
    await db.update(
      AppConstants.tablaVentas,
      {
        'estado': venta.estado.name,
        'metodoPago': venta.metodoPago?.name,
        'cajeroId': venta.cajeroId,
        'fechaCobro': venta.fechaCobro?.toIso8601String(),
        'clienteId': venta.clienteId,
      },
      where: 'id = ?',
      whereArgs: [venta.id],
    );
    // El encolado a sync_queue lo hace VentaRepositoryImpl.
  }
}
