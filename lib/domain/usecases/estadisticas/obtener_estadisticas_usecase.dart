import '../../entities/venta.dart';
import '../../repositories/venta_repository.dart';
import '../../repositories/producto_repository.dart';

/// Resumen de costo/impuestos/utilidad de un producto en el período,
/// igual a como se calcula en la planilla de control diario:
/// UTILIDAD = VENTA - (COSTO * cantidad) - IIBB - TSH.
class ResumenProducto {
  final String nombreProducto;
  final double cantidadVendida;
  final double facturacion;
  final double costoTotal;
  final double iibbTotal;
  final double tshTotal;

  const ResumenProducto({
    required this.nombreProducto,
    required this.cantidadVendida,
    required this.facturacion,
    required this.costoTotal,
    required this.iibbTotal,
    required this.tshTotal,
  });

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
/// impuestos (IIBB/TSH) y utilidad real por producto.
class ObtenerEstadisticasUseCase {
  final VentaRepository _ventaRepository;
  final ProductoRepository _productoRepository;
  ObtenerEstadisticasUseCase(this._ventaRepository, this._productoRepository);

  Future<EstadisticasResumen> call(DateTime desde, DateTime hasta) async {
    final todas = await _ventaRepository.obtenerPorRangoFechaGlobal(desde, hasta);
    final cobradas = todas.where((v) => v.estado == EstadoVenta.cobrada).toList();
    final productos = await _productoRepository.obtenerTodos();
    final productoPorId = {for (final p in productos) p.id: p};

    double facturacionTotal = 0;
    final cantidadPorProducto = <String, double>{};
    final facturacionPorVendedor = <String, double>{};
    final resumenPorProducto = <String, ResumenProducto>{};
    final facturacionPorMetodoPago = <MetodoPago, double>{};

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

        final producto = productoPorId[item.productoId];
        final costoUnit = producto?.costoUnitario ?? 0;
        final iibbUnit = producto?.tasaIIBB ?? 0;
        final tshUnit = producto?.tasaTSH ?? 0;

        final existente = resumenPorProducto[item.productoId];
        resumenPorProducto[item.productoId] = ResumenProducto(
          nombreProducto: item.nombreProducto,
          cantidadVendida: (existente?.cantidadVendida ?? 0) + item.cantidad,
          facturacion: (existente?.facturacion ?? 0) + item.precioTotal,
          costoTotal: (existente?.costoTotal ?? 0) + (costoUnit * item.cantidad),
          iibbTotal: (existente?.iibbTotal ?? 0) + (iibbUnit * item.cantidad),
          tshTotal: (existente?.tshTotal ?? 0) + (tshUnit * item.cantidad),
        );
      }
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
