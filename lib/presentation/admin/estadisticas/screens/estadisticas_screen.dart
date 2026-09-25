import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/dia_laboral_service.dart';
import '../../../../domain/entities/venta.dart';
import '../../../../domain/usecases/estadisticas/obtener_estadisticas_usecase.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/stat_card.dart';
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
      appBar: GradientAppBar(
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
              data: (stats) => _ContenidoEstadisticas(stats: stats, periodo: periodo),
              loading: () => const LoadingWidget(),
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
  final _Periodo periodo;
  const _ContenidoEstadisticas({required this.stats, required this.periodo});

  @override
  Widget build(BuildContext context) {
    final masVendidos = stats.productosMasVendidos();
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_eyebrowPeriodo(periodo), style: AppTheme.eyebrowStyle(context)),
        const SizedBox(height: 6),
        Text(
          Formatters.formatearMoneda(stats.facturacionTotal),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 40),
        ),
        const SizedBox(height: 4),
        Text('${stats.cantidadVentas} ventas', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        StatCard(
          label: 'Promedio por venta',
          value: Formatters.formatearMoneda(stats.promedioPorVenta),
          icon: Icons.equalizer_rounded,
        ),
        const SizedBox(height: 24),
        const _SectionHeader(titulo: 'Costo, impuestos y utilidad'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Costo total',
                value: Formatters.formatearMoneda(stats.costoTotalGeneral),
                icon: Icons.inventory_2_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Utilidad',
                value: Formatters.formatearMoneda(stats.utilidadTotalGeneral),
                icon: Icons.trending_up_rounded,
                destacado: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'IIBB',
                value: Formatters.formatearMoneda(stats.iibbTotalGeneral),
                icon: Icons.receipt_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'TSH',
                value: Formatters.formatearMoneda(stats.tshTotalGeneral),
                icon: Icons.receipt_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          titulo: 'Productos',
          subtitulo: 'Costo, IIBB y TSH calculados automáticamente sobre cada venta.',
        ),
        const SizedBox(height: 12),
        if (stats.resumenPorProducto.isEmpty)
          const EmptyState(icon: Icons.bar_chart_rounded, message: 'Sin datos en este período.')
        else
          ...stats.resumenPorProducto.values.map(
            (r) => Card(
              child: ExpansionTile(
                leading: Icon(Icons.eco_rounded, color: colorScheme.onSurfaceVariant),
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
        const _SectionHeader(titulo: 'Productos más vendidos'),
        const SizedBox(height: 12),
        if (masVendidos.isEmpty)
          const EmptyState(
            icon: Icons.shopping_basket_outlined,
            message: 'No hay ventas cobradas en este período todavía.',
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
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => colorScheme.inverseSurface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                          '${masVendidos[group.x].key}\n${Formatters.formatearCantidad(rod.toY)}',
                          TextStyle(
                            color: colorScheme.onInverseSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < masVendidos.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: masVendidos[i].value,
                            width: 24,
                            borderRadius: BorderRadius.circular(6),
                            color: i == 0 ? colorScheme.primary : colorScheme.primary.withOpacity(0.35),
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
                              child: Text(
                                masVendidos[i].key,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: Theme.of(context).textTheme.bodySmall,
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
          ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 24),
        const _SectionHeader(titulo: 'Ventas por método de pago'),
        const SizedBox(height: 12),
        if (stats.facturacionPorMetodoPago.isEmpty)
          const EmptyState(icon: Icons.payments_outlined, message: 'Sin datos en este período.')
        else
          Card(
            child: Column(
              children: [
                for (final e in stats.facturacionPorMetodoPago.entries)
                  _FilaMetodoPago(
                    metodo: e.key,
                    monto: e.value,
                    proporcion: stats.facturacionTotal > 0 ? e.value / stats.facturacionTotal : 0,
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
      ],
    );
  }
}

String _eyebrowPeriodo(_Periodo periodo) => switch (periodo) {
      _Periodo.dia => 'HOY',
      _Periodo.semana => 'ESTA SEMANA',
      _Periodo.mes => 'ESTE MES',
    };

/// Encabezado de sección: solo tipografía (etiqueta en versalitas +
/// título), sin ícono en caja tintada — el acento de color de la marca
/// se reserva para un solo elemento por pantalla.
class _SectionHeader extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  const _SectionHeader({required this.titulo, this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: theme.textTheme.titleMedium),
        if (subtitulo != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitulo!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Fila de una tarjeta "Ventas por método de pago": ícono propio del
/// método, monto, y una barra de proporción sobre el total facturado
/// (en vez de una lista de ListTiles sueltos sin jerarquía visual).
class _FilaMetodoPago extends StatelessWidget {
  final MetodoPago metodo;
  final double monto;
  final double proporcion;
  const _FilaMetodoPago({required this.metodo, required this.monto, required this.proporcion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconoMetodoPago(metodo), size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(_labelMetodoPago(metodo), style: theme.textTheme.bodyLarge)),
              Text(
                Formatters.formatearMoneda(monto),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: proporcion.clamp(0, 1),
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconoMetodoPago(MetodoPago m) => switch (m) {
      MetodoPago.efectivo => Icons.payments_rounded,
      MetodoPago.transferencia => Icons.swap_horiz_rounded,
      MetodoPago.debito => Icons.credit_card_rounded,
      MetodoPago.credito => Icons.credit_card_rounded,
      MetodoPago.cuentaCorriente => Icons.account_balance_wallet_rounded,
    };

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
