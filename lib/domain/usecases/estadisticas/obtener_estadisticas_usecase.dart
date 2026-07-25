import '../../entities/venta.dart';
import '../../repositories/venta_repository.dart';

/// Modelo de resultado con las métricas del panel de estadísticas.
class EstadisticasResumen {
  final double facturacionTotal;
  final int cantidadVentas;
  final double promedioPorVenta;
  final Map<String, double> cantidadVendidaPorProducto; // nombreProducto -> cantidad
  final Map<String, double> facturacionPorVendedor; // vendedorId -> total

  const EstadisticasResumen({
    required this.facturacionTotal,
    required this.cantidadVentas,
    required this.promedioPorVenta,
    required this.cantidadVendidaPorProducto,
    required this.facturacionPorVendedor,
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
}

/// Caso de uso: calcula estadísticas (día/semana/mes) a partir de las
/// ventas cobradas en el rango de fechas solicitado.
class ObtenerEstadisticasUseCase {
  final VentaRepository _ventaRepository;
  ObtenerEstadisticasUseCase(this._ventaRepository);

  Future<EstadisticasResumen> call(DateTime desde, DateTime hasta) async {
    final todas = await _ventaRepository.obtenerPorRangoFechaGlobal(desde, hasta);
    final cobradas = todas.where((v) => v.estado == EstadoVenta.cobrada).toList();

    double facturacionTotal = 0;
    final cantidadPorProducto = <String, double>{};
    final facturacionPorVendedor = <String, double>{};

    for (final venta in cobradas) {
      facturacionTotal += venta.total;
      facturacionPorVendedor.update(
        venta.vendedorId,
        (actual) => actual + venta.total,
        ifAbsent: () => venta.total,
      );
      for (final item in venta.detalle) {
        cantidadPorProducto.update(
          item.nombreProducto,
          (actual) => actual + item.cantidad,
          ifAbsent: () => item.cantidad,
        );
      }
    }

    return EstadisticasResumen(
      facturacionTotal: facturacionTotal,
      cantidadVentas: cobradas.length,
      promedioPorVenta: cobradas.isEmpty ? 0 : facturacionTotal / cobradas.length,
      cantidadVendidaPorProducto: cantidadPorProducto,
      facturacionPorVendedor: facturacionPorVendedor,
    );
  }
}
