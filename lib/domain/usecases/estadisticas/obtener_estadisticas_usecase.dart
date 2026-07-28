import '../../entities/venta.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/producto_repository.dart';
import '../../../core/services/configuracion_impuestos.dart';

/// Resumen de costo/impuestos/utilidad de un producto en el período.
/// Fórmula tomada de la planilla de control diario:
///   promedioVenta = facturacion / cantidadVendida
///   IIBB = facturacion * tasaIIBB   (equivale a promedioVenta*tasaIIBB*cantidad)
///   TSH  = facturacion * tasaTSH
///   contribucionMarginal (por unidad) = promedioVenta - costoUnitario - iibbPorUnidad - tshPorUnidad
///   UTILIDAD = facturacion - costoTotal - IIBB - TSH
class ResumenProducto {
  final String nombreProducto;
  final double cantidadVendida;
  final double facturacion;
  final double costoUnitario;
  final double costoTotal;
  final double iibbTotal;
  final double tshTotal;

  const ResumenProducto({
    required this.nombreProducto,
    required this.cantidadVendida,
    required this.facturacion,
    required this.costoUnitario,
    required this.costoTotal,
    required this.iibbTotal,
    required this.tshTotal,
  });

  double get promedioVenta => cantidadVendida > 0 ? facturacion / cantidadVendida : 0;

  /// Contribución marginal POR UNIDAD (precio promedio menos costo e
  /// impuestos, todo por unidad), igual que la fila "CONT MARG" de la
  /// planilla.
  double get contribucionMarginalUnitaria {
    if (cantidadVendida <= 0) return 0;
    final iibbPorUnidad = iibbTotal / cantidadVendida;
    final tshPorUnidad = tshTotal / cantidadVendida;
    return promedioVenta - costoUnitario - iibbPorUnidad - tshPorUnidad;
  }

  double get utilidad => facturacion - costoTotal - iibbTotal - tshTotal;
}

/// Modelo de resultado con las métricas del panel de estadísticas.
class EstadisticasResumen {
  final double facturacionTotal;
  final int cantidadVentas;
  final double promedioPorVenta;
  final Map<String, double> cantidadVendidaPorProducto; // nombreProducto -> cantidad
  final Map<String, double> facturacionPorVendedor; // vendedorId -> total
  final Map<String, ResumenProducto> resumenPorProducto; // productoId -> resumen
  final Map<MetodoPago, double> facturacionPorMetodoPago;

  const EstadisticasResumen({
    required this.facturacionTotal,
    required this.cantidadVentas,
    required this.promedioPorVenta,
    required this.cantidadVendidaPorProducto,
    required this.facturacionPorVendedor,
    required this.resumenPorProducto,
    required this.facturacionPorMetodoPago,
  });

  /// Top N productos por cantidad vendida, de mayor a menor.
  List<MapEntry<String, double>> productosMasVendidos([int top = 5]) {
    final entradas = cantidadVendidaPorProducto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entradas.take(top).toList();
  }

  /// Los N productos con menor cantidad vendida (pero que sí se vendieron
  /// al menos una vez en el período).
  List<MapEntry<String, double>> productosMenosVendidos([int top = 5]) {
    final entradas = cantidadVendidaPorProducto.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entradas.take(top).toList();
  }

  double get costoTotalGeneral =>
      resumenPorProducto.values.fold(0.0, (acc, r) => acc + r.costoTotal);
  double get iibbTotalGeneral => resumenPorProducto.values.fold(0.0, (acc, r) => acc + r.iibbTotal);
  double get tshTotalGeneral => resumenPorProducto.values.fold(0.0, (acc, r) => acc + r.tshTotal);
  double get utilidadTotalGeneral =>
      resumenPorProducto.values.fold(0.0, (acc, r) => acc + r.utilidad);
}

/// Caso de uso: calcula estadísticas (día/semana/mes) a partir de las
/// ventas cobradas en el rango de fechas solicitado, incluyendo costo,
/// impuestos (IIBB/TSH, calculados automáticamente como % de la venta,
/// igual que en la planilla) y utilidad real por producto.
class ObtenerEstadisticasUseCase {
  final VentaRepository _ventaRepository;
  final ProductoRepository _productoRepository;
  ObtenerEstadisticasUseCase(this._ventaRepository, this._productoRepository);

  Future<EstadisticasResumen> call(DateTime desde, DateTime hasta) async {
    final todas = await _ventaRepository.obtenerPorRangoFechaGlobal(desde, hasta);
    final cobradas = todas.where((v) => v.estado == EstadoVenta.cobrada).toList();
    final productos = await _productoRepository.obtenerTodos();
    final productoPorId = {for (final p in productos) p.id: p};

    final tasaIIBB = await ConfiguracionImpuestos.obtenerTasaIIBB();
    final tasaTSH = await ConfiguracionImpuestos.obtenerTasaTSH();

    double facturacionTotal = 0;
    final cantidadPorProducto = <String, double>{};
    final facturacionPorVendedor = <String, double>{};
    final facturacionPorMetodoPago = <MetodoPago, double>{};

    // Primero se acumula cantidad y facturación por producto (necesario
    // para poder calcular costo/IIBB/TSH una sola vez al final).
    final cantidadPorProductoId = <String, double>{};
    final facturacionPorProductoId = <String, double>{};
    final nombrePorProductoId = <String, String>{};

    for (final venta in cobradas) {
      facturacionTotal += venta.total;
      facturacionPorVendedor.update(
        venta.vendedorId,
        (actual) => actual + venta.total,
        ifAbsent: () => venta.total,
      );
      if (venta.metodoPago != null) {
        facturacionPorMetodoPago.update(
          venta.metodoPago!,
          (actual) => actual + venta.total,
          ifAbsent: () => venta.total,
        );
      }
      for (final item in venta.detalle) {
        cantidadPorProducto.update(
          item.nombreProducto,
          (actual) => actual + item.cantidad,
          ifAbsent: () => item.cantidad,
        );
        cantidadPorProductoId.update(
          item.productoId,
          (actual) => actual + item.cantidad,
          ifAbsent: () => item.cantidad,
        );
        facturacionPorProductoId.update(
          item.productoId,
          (actual) => actual + item.precioTotal,
          ifAbsent: () => item.precioTotal,
        );
        nombrePorProductoId[item.productoId] = item.nombreProducto;
      }
    }

    final resumenPorProducto = <String, ResumenProducto>{};
    for (final productoId in cantidadPorProductoId.keys) {
      final facturacionProducto = facturacionPorProductoId[productoId] ?? 0;
      final costoUnit = productoPorId[productoId]?.costoUnitario ?? 0;
      final cantidad = cantidadPorProductoId[productoId] ?? 0;

      resumenPorProducto[productoId] = ResumenProducto(
        nombreProducto: nombrePorProductoId[productoId] ?? '(producto eliminado)',
        cantidadVendida: cantidad,
        facturacion: facturacionProducto,
        costoUnitario: costoUnit,
        costoTotal: costoUnit * cantidad,
        iibbTotal: facturacionProducto * tasaIIBB,
        tshTotal: facturacionProducto * tasaTSH,
      );
    }

    return EstadisticasResumen(
      facturacionTotal: facturacionTotal,
      cantidadVentas: cobradas.length,
      promedioPorVenta: cobradas.isEmpty ? 0 : facturacionTotal / cobradas.length,
      cantidadVendidaPorProducto: cantidadPorProducto,
      facturacionPorVendedor: facturacionPorVendedor,
      resumenPorProducto: resumenPorProducto,
      facturacionPorMetodoPago: facturacionPorMetodoPago,
    );
  }
}
