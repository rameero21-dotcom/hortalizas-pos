import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/usecases/estadisticas/obtener_estadisticas_usecase.dart';

enum _Periodo { dia, semana, mes }

class _RangoFechas {
  final DateTime desde;
  final DateTime hasta;
  _RangoFechas(this.desde, this.hasta);
}

_RangoFechas _rangoParaPeriodo(_Periodo periodo) {
  final ahora = DateTime.now();
  final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);
  switch (periodo) {
    case _Periodo.dia:
      return _RangoFechas(hoyInicio, hoyInicio.add(const Duration(days: 1)));
    case _Periodo.semana:
      final inicioSemana = hoyInicio.subtract(Duration(days: hoyInicio.weekday - 1));
      return _RangoFechas(inicioSemana, inicioSemana.add(const Duration(days: 7)));
    case _Periodo.mes:
      final inicioMes = DateTime(ahora.year, ahora.month, 1);
      final inicioProximoMes = DateTime(ahora.year, ahora.month + 1, 1);
      return _RangoFechas(inicioMes, inicioProximoMes);
  }
}

final _periodoSeleccionadoProvider = StateProvider<_Periodo>((ref) => _Periodo.dia);

final _estadisticasProvider = FutureProvider.autoDispose<EstadisticasResumen>((ref) {
  final periodo = ref.watch(_periodoSeleccionadoProvider);
  final rango = _rangoParaPeriodo(periodo);
  return ref.watch(obtenerEstadisticasUseCaseProvider).call(rango.desde, rango.hasta);
});

/// Panel de estadísticas: ventas del día/semana/mes, facturación,
/// productos más y menos vendidos, promedio por venta, ventas por
/// vendedor, y gráfico de barras.
class EstadisticasScreen extends ConsumerWidget {
  const EstadisticasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(_periodoSeleccionadoProvider);
    final estadisticasAsync = ref.watch(_estadisticasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<_Periodo>(
              segments: const [
                ButtonSegment(value: _Periodo.dia, label: Text('Día')),
                ButtonSegment(value: _Periodo.semana, label: Text('Semana')),
                ButtonSegment(value: _Periodo.mes, label: Text('Mes')),
              ],
              selected: {periodo},
              onSelectionChanged: (nuevo) =>
                  ref.read(_periodoSeleccionadoProvider.notifier).state = nuevo.first,
            ),
          ),
          Expanded(
            child: estadisticasAsync.when(
              data: (stats) => _ContenidoEstadisticas(stats: stats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No se pudieron cargar las estadísticas (¿hay conexión?).\n$err',
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContenidoEstadisticas extends StatelessWidget {
  final EstadisticasResumen stats;
  const _ContenidoEstadisticas({required this.stats});

  @override
  Widget build(BuildContext context) {
    final masVendidos = stats.productosMasVendidos();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _TarjetaMetrica(
                titulo: 'Facturación',
                valor: Formatters.formatearMoneda(stats.facturacionTotal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TarjetaMetrica(titulo: 'Ventas', valor: '${stats.cantidadVentas}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TarjetaMetrica(
          titulo: 'Promedio por venta',
          valor: Formatters.formatearMoneda(stats.promedioPorVenta),
        ),
        const SizedBox(height: 24),
        const Text('Productos más vendidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        if (masVendidos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No hay ventas cobradas en este período todavía.'),
          )
        else
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: [
                  for (int i = 0; i < masVendidos.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: masVendidos[i].value, width: 24),
                    ]),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= masVendidos.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(masVendidos[i].key, style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Text('Ventas por vendedor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (stats.facturacionPorVendedor.isEmpty)
          const Text('Sin datos en este período.')
        else
          ...stats.facturacionPorVendedor.entries.map(
            (e) => ListTile(
              title: Text(e.key),
              trailing: Text(Formatters.formatearMoneda(e.value)),
            ),
          ),
      ],
    );
  }
}

class _TarjetaMetrica extends StatelessWidget {
  final String titulo;
  final String valor;
  const _TarjetaMetrica({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
