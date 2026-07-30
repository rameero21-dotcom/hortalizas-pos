import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/venta.dart';
import '../../../../domain/entities/caja.dart';

class _FiltrosHistorial {
  final DateTime desde;
  final DateTime hasta;
  final String busqueda;

  _FiltrosHistorial({required this.desde, required this.hasta, this.busqueda = ''});

  _FiltrosHistorial copyWith({DateTime? desde, DateTime? hasta, String? busqueda}) {
    return _FiltrosHistorial(
      desde: desde ?? this.desde,
      hasta: hasta ?? this.hasta,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

final _filtrosProvider = StateProvider<_FiltrosHistorial>((ref) {
  final ahora = DateTime.now();
  return _FiltrosHistorial(
    desde: DateTime(ahora.year, ahora.month, 1),
    hasta: DateTime(ahora.year, ahora.month + 1, 1),
  );
});

final _ventasHistorialProvider = FutureProvider.autoDispose<List<Venta>>((ref) async {
  final filtros = ref.watch(_filtrosProvider);
  final repo = ref.watch(ventaRepositoryProvider);
  final todas = await repo.obtenerPorRangoFechaGlobal(filtros.desde, filtros.hasta);
  final cobradas = todas.where((v) => v.estado == EstadoVenta.cobrada).toList();
  if (filtros.busqueda.trim().isEmpty) return cobradas;

  final q = filtros.busqueda.trim().toLowerCase();
  return cobradas.where((v) {
    final matchNumero = v.numero.toString().contains(q);
    final matchProducto = v.detalle.any((d) => d.nombreProducto.toLowerCase().contains(q));
    final matchVendedor = v.vendedorId.toLowerCase().contains(q);
    final matchNombreReferencia = (v.nombreCliente ?? '').toLowerCase().contains(q);
    return matchNumero || matchProducto || matchVendedor || matchNombreReferencia;
  }).toList();
});

/// Un ítem unificado de la línea de tiempo de caja: puede ser una venta
/// cobrada o un movimiento manual (ingreso/egreso), todo junto y
/// ordenado por fecha.
class _MovimientoUnificado {
  final String id;
  final bool esVenta;
  final DateTime fecha;
  final String titulo;
  final String subtitulo;
  final double monto;
  final Color color;

  _MovimientoUnificado({
    required this.id,
    required this.esVenta,
    required this.fecha,
    required this.titulo,
    required this.subtitulo,
    required this.monto,
    required this.color,
  });
}

final _movimientosCajaHistorialProvider = FutureProvider.autoDispose<List<_MovimientoUnificado>>((ref) async {
  final filtros = ref.watch(_filtrosProvider);
  final movimientos = await ref.watch(cajaRepositoryProvider).obtenerMovimientosGlobal(filtros.desde, filtros.hasta);

  final unificados = <_MovimientoUnificado>[];

  for (final m in movimientos) {
    final esIngreso = m.tipo == TipoMovimientoCaja.ingreso;
    unificados.add(_MovimientoUnificado(
      id: m.id,
      esVenta: false,
      fecha: m.fecha,
      titulo: esIngreso ? 'Ingreso manual' : 'Egreso manual',
      subtitulo: '${m.detalle} (${m.metodo == MetodoMovimientoCaja.efectivo ? 'Efectivo' : 'Transferencia'})',
      monto: esIngreso ? m.monto : -m.monto,
      color: esIngreso ? Colors.blue.shade300 : Colors.red.shade300,
    ));
  }

  unificados.sort((a, b) => b.fecha.compareTo(a.fecha));
  return unificados;
});

String _labelMetodoPago(MetodoPago m) => switch (m) {
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.transferencia => 'Transferencia',
      MetodoPago.debito => 'Débito',
      MetodoPago.credito => 'Crédito',
      MetodoPago.cuentaCorriente => 'Cuenta corriente',
    };

/// Búsqueda de ventas cobradas por fecha, número, producto o vendedor,
/// más un apartado con todos los movimientos de caja (ventas, ingresos
/// y egresos manuales) juntos en una sola línea de tiempo.
class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _generandoPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _elegirRango(BuildContext context, WidgetRef ref) async {
    final filtros = ref.read(_filtrosProvider);
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: filtros.desde, end: filtros.hasta),
    );
    if (rango != null) {
      ref.read(_filtrosProvider.notifier).state = filtros.copyWith(
        desde: rango.start,
        hasta: rango.end.add(const Duration(days: 1)),
      );
    }
  }

  /// Junta todos los datos del período (ventas, estadísticas, caja,
  /// clientes) y arma el PDF, para después dejar que el usuario lo
  /// guarde o comparta con el selector nativo del sistema.
  Future<void> _exportarPdf(_FiltrosHistorial filtros) async {
    setState(() => _generandoPdf = true);
    try {
      final ventasRepo = ref.read(ventaRepositoryProvider);
      final todasLasVentas = await ventasRepo.obtenerPorRangoFechaGlobal(filtros.desde, filtros.hasta);
      final ventasCobradas = todasLasVentas.where((v) => v.estado == EstadoVenta.cobrada).toList();

      final estadisticas =
          await ref.read(obtenerEstadisticasUseCaseProvider).call(filtros.desde, filtros.hasta);

      final movimientosCaja =
          await ref.read(cajaRepositoryProvider).obtenerMovimientosGlobal(filtros.desde, filtros.hasta);

      final clienteRepo = ref.read(clienteRepositoryProvider);
      final clientes = await clienteRepo.obtenerTodos();
      final movimientosCuentaCorriente =
          await clienteRepo.obtenerMovimientosCuentaGlobal(filtros.desde, filtros.hasta);

      final bytes = await ref.read(reportePdfServiceProvider).generar(
            desde: filtros.desde,
            hasta: filtros.hasta,
            ventas: ventasCobradas,
            estadisticas: estadisticas,
            movimientosCaja: movimientosCaja,
            clientes: clientes,
            movimientosCuentaCorriente: movimientosCuentaCorriente,
          );

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'reporte_${Formatters.formatearFecha(filtros.desde).replaceAll('/', '-')}_a_${Formatters.formatearFecha(filtros.hasta.subtract(const Duration(days: 1))).replaceAll('/', '-')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ref.watch(_filtrosProvider);
    final ventasAsync = ref.watch(_ventasHistorialProvider);
    final movimientosAsync = ref.watch(_movimientosCajaHistorialProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: _generandoPdf
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF del período seleccionado',
            onPressed: _generandoPdf ? null : () => _exportarPdf(filtros),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ventas'),
            Tab(text: 'Movimientos de caja'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_tabController.index == 0)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) =>
                        ref.read(_filtrosProvider.notifier).state = filtros.copyWith(busqueda: v),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${Formatters.formatearFecha(filtros.desde)} — ${Formatters.formatearFecha(filtros.hasta.subtract(const Duration(days: 1)))}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _elegirRango(context, ref),
                      icon: const Icon(Icons.date_range),
                      label: const Text('Cambiar rango'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ===== Pestaña: Ventas =====
                ventasAsync.when(
                  data: (ventas) {
                    if (ventas.isEmpty) {
                      return const Center(child: Text('No hay ventas cobradas en este rango.'));
                    }
                    return ListView.builder(
                      itemCount: ventas.length,
                      itemBuilder: (context, index) {
                        final venta = ventas[index];
                        return Dismissible(
                          key: ValueKey(venta.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Eliminar venta'),
                                    content: Text(
                                        '¿Eliminar la venta #${venta.numero}? Esta acción no se puede deshacer.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          onDismissed: (_) async {
                            await ref.read(ventaRepositoryProvider).eliminarVenta(venta.id);
                            ref.invalidate(_ventasHistorialProvider);
                            ref.invalidate(_movimientosCajaHistorialProvider);
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.receipt_long_rounded,
                                    size: 20, color: Theme.of(context).colorScheme.primary),
                              ),
                              title: Text(
                                venta.nombreCliente != null && venta.nombreCliente!.isNotEmpty
                                    ? 'Venta #${venta.numero} · ${venta.nombreCliente}'
                                    : 'Venta #${venta.numero}',
                              ),
                              subtitle: Text(
                                  '${Formatters.formatearFechaHora(venta.fecha)} · ${venta.detalle.length} producto(s)'
                                  '${venta.vendedorNombre != null ? ' · Vend: ${venta.vendedorNombre}' : ''}'),
                              trailing: Text(
                                Formatters.formatearMoneda(venta.total),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            onTap: () => showModalBottomSheet(
                              context: context,
                              builder: (_) => _DetalleVentaHistorial(venta: venta),
                            ),
                          ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, __) => Center(child: Text('Error: $err')),
                ),
                // ===== Pestaña: Movimientos de caja (ventas + ingresos + egresos) =====
                movimientosAsync.when(
                  data: (movimientos) {
                    if (movimientos.isEmpty) {
                      return const Center(child: Text('No hay movimientos en este rango.'));
                    }
                    return ListView.builder(
                      itemCount: movimientos.length,
                      itemBuilder: (context, index) {
                        final m = movimientos[index];
                        return Dismissible(
                          key: ValueKey('${m.esVenta}_${m.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Eliminar ${m.esVenta ? 'venta' : 'movimiento'}'),
                                    content: Text(
                                        '¿Eliminar "${m.titulo}"? Esta acción no se puede deshacer.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          onDismissed: (_) async {
                            if (m.esVenta) {
                              await ref.read(ventaRepositoryProvider).eliminarVenta(m.id);
                              ref.invalidate(_ventasHistorialProvider);
                            } else {
                              await ref.read(cajaRepositoryProvider).eliminarMovimiento(m.id);
                            }
                            ref.invalidate(_movimientosCajaHistorialProvider);
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: m.color.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  m.titulo.startsWith('Egreso')
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  size: 20,
                                  color: m.color,
                                ),
                              ),
                              title: Text(m.titulo),
                              subtitle: Text('${m.subtitulo} · ${Formatters.formatearFechaHora(m.fecha)}'),
                              trailing: Text(
                                Formatters.formatearMoneda(m.monto),
                                style: TextStyle(fontWeight: FontWeight.bold, color: m.color),
                              ),
                          ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, __) => Center(child: Text('Error: $err')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetalleVentaHistorial extends StatelessWidget {
  final Venta venta;
  const _DetalleVentaHistorial({required this.venta});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Venta #${venta.numero}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(Formatters.formatearFechaHora(venta.fecha)),
            const Divider(),
            ...venta.detalle.map((d) => ListTile(
                  dense: true,
                  title: Text(d.nombreProducto),
                  subtitle: Text('Cantidad: ${Formatters.formatearCantidad(d.cantidad)}'),
                  trailing: Text(Formatters.formatearMoneda(d.precioTotal)),
                )),
            const Divider(),
            Text('Total: ${Formatters.formatearMoneda(venta.total)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (venta.metodoPago != null) Text('Pago: ${_labelMetodoPago(venta.metodoPago!)}'),
          ],
        ),
      ),
    );
  }
}
