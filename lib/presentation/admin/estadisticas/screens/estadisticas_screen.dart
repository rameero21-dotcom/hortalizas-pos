import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/dia_laboral_service.dart';
import '../../../../domain/entities/venta.dart';
import '../../../../domain/usecases/estadisticas/obtener_estadisticas_usecase.dart';
import 'configuracion_impuestos_screen.dart';

enum _Periodo { dia, semana, mes }

class _RangoFechas {
  final DateTime desde;
  final DateTime hasta;
  _RangoFechas(this.desde, this.hasta);
}

/// Usa la MISMA hora de corte configurada en Arqueo de Caja, para que
/// "el día" signifique lo mismo en las dos pantallas — si el negocio
/// trabaja de noche hasta la mañana siguiente, esa jornada completa
/// cuenta como un solo día en las estadísticas también, en vez de
/// partirse en dos por cruzar la medianoche.
Future<_RangoFechas> _rangoParaPeriodo(_Periodo periodo) async {
  final rangoHoy = await DiaLaboralService.rangoDeHoy();
  switch (periodo) {
    case _Periodo.dia:
      return _RangoFechas(rangoHoy.inicio, rangoHoy.fin);
    case _Periodo.semana:
      final inicioSemana = rangoHoy.inicio.subtract(Duration(days: rangoHoy.inicio.weekday - 1));
      return _RangoFechas(inicioSemana, inicioSemana.add(const Duration(days: 7)));
    case _Periodo.mes:
      final horaCorte = rangoHoy.inicio.hour;
      final inicioMes = DateTime(rangoHoy.inicio.year, rangoHoy.inicio.month, 1, horaCorte);
      final inicioProximoMes = DateTime(rangoHoy.inicio.year, rangoHoy.inicio.month + 1, 1, horaCorte);
      return _RangoFechas(inicioMes, inicioProximoMes);
  }
}

final _periodoSeleccionadoProvider = StateProvider<_Periodo>((ref) => _Periodo.dia);

final _estadisticasProvider = FutureProvider.autoDispose<EstadisticasResumen>((ref) async {
  final periodo = ref.watch(_periodoSeleccionadoProvider);
  final rango = await _rangoParaPeriodo(periodo);
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
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Porcentajes de IIBB y TSH',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfiguracionImpuestosScreen()),
              ).then((_) => ref.invalidate(_estadisticasProvider));
            },
          ),
        ],
      ),
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
        const Text('Costo, impuestos y utilidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TarjetaMetrica(
                titulo: 'Costo total',
                valor: Formatters.formatearMoneda(stats.costoTotalGeneral),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TarjetaMetrica(
                titulo: 'Utilidad',
                valor: Formatters.formatearMoneda(stats.utilidadTotalGeneral),
                destacado: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TarjetaMetrica(
                titulo: 'IIBB',
                valor: Formatters.formatearMoneda(stats.iibbTotalGeneral),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TarjetaMetrica(
                titulo: 'TSH',
                valor: Formatters.formatearMoneda(stats.tshTotalGeneral),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text(
          'Costo, IIBB y TSH calculados automáticamente sobre cada venta.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (stats.resumenPorProducto.isEmpty)
          const Text('Sin datos en este período.')
        else
          ...stats.resumenPorProducto.values.map(
            (r) => Card(
              child: ExpansionTile(
                title: Text(r.nombreProducto),
                subtitle: Text(
                  'Cant: ${r.cantidadVendida.toStringAsFixed(0)} · '
                  'Venta: ${Formatters.formatearMoneda(r.facturacion)}',
                ),
                trailing: Text(
                  Formatters.formatearMoneda(r.utilidad),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: r.utilidad >= 0 ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                children: [
                  _FilaDetalleProducto('Precio promedio de venta', r.promedioVenta),
                  _FilaDetalleProducto('Costo (unitario)', r.costoUnitario),
                  _FilaDetalleProducto('Costo total', r.costoTotal),
                  _FilaDetalleProducto('IIBB', r.iibbTotal),
                  _FilaDetalleProducto('TSH', r.tshTotal),
                  _FilaDetalleProducto('Contribución marginal (por unidad)', r.contribucionMarginalUnitaria),
                  _FilaDetalleProducto('Utilidad', r.utilidad, destacado: true),
                ],
              ),
            ),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barGroups: [
                      for (int i = 0; i < masVendidos.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: masVendidos[i].value,
                            width: 24,
                            borderRadius: BorderRadius.circular(6),
                            color: i == 0
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ]),
                    ],
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
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
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Text('Ventas por método de pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (stats.facturacionPorMetodoPago.isEmpty)
          const Text('Sin datos en este período.')
        else
          ...stats.facturacionPorMetodoPago.entries.map(
            (e) => ListTile(
              title: Text(_labelMetodoPago(e.key)),
              trailing: Text(Formatters.formatearMoneda(e.value)),
            ),
          ),
      ],
    );
  }
}

String _labelMetodoPago(MetodoPago m) => switch (m) {
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.transferencia => 'Transferencia',
      MetodoPago.debito => 'Débito',
      MetodoPago.credito => 'Crédito',
      MetodoPago.cuentaCorriente => 'Cuenta corriente (fiado)',
    };

class _FilaDetalleProducto extends StatelessWidget {
  final String label;
  final double valor;
  final bool destacado;
  const _FilaDetalleProducto(this.label, this.valor, {this.destacado = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: destacado ? FontWeight.bold : FontWeight.normal)),
          Text(
            Formatters.formatearMoneda(valor),
            style: TextStyle(
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
              color: destacado ? (valor >= 0 ? Colors.green.shade300 : Colors.red.shade300) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMetrica extends StatelessWidget {
  final String titulo;
  final String valor;
  final bool destacado;
  const _TarjetaMetrica({required this.titulo, required this.valor, this.destacado = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: destacado ? colorScheme.secondary.withOpacity(0.15) : null,
      shape: destacado
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.secondary),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: destacado ? colorScheme.secondary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
