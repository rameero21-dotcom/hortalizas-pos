import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/venta.dart';

class _FiltrosFacturacion {
  final DateTime desde;
  final DateTime hasta;
  _FiltrosFacturacion({required this.desde, required this.hasta});
}

final _filtrosFacturacionProvider = StateProvider<_FiltrosFacturacion>((ref) {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  return _FiltrosFacturacion(desde: hoy, hasta: hoy.add(const Duration(days: 1)));
});

/// Una parte transferida de una venta (una venta con pago dividido
/// puede aportar solo una porción de su total acá).
class _ItemFacturacion {
  final Venta venta;
  final double montoTransferido;
  _ItemFacturacion({required this.venta, required this.montoTransferido});
}

final _facturacionProvider = FutureProvider.autoDispose<List<_ItemFacturacion>>((ref) async {
  final filtros = ref.watch(_filtrosFacturacionProvider);
  final repo = ref.watch(ventaRepositoryProvider);
  final todas = await repo.obtenerPorRangoFechaGlobal(filtros.desde, filtros.hasta);
  final cobradas = todas.where((v) => v.estado == EstadoVenta.cobrada);

  final items = <_ItemFacturacion>[];
  for (final v in cobradas) {
    double montoTransferido = 0;
    if (v.pagos.isNotEmpty) {
      montoTransferido = v.pagos
          .where((p) => p.metodo == MetodoPago.transferencia)
          .fold(0.0, (acc, p) => acc + p.monto);
    } else if (v.metodoPago == MetodoPago.transferencia) {
      montoTransferido = v.total;
    }
    if (montoTransferido > 0) {
      items.add(_ItemFacturacion(venta: v, montoTransferido: montoTransferido));
    }
  }
  items.sort((a, b) => b.venta.fecha.compareTo(a.venta.fecha));
  return items;
});

/// Pantalla pensada para el contador: solo lo que se cobró por
/// transferencia, con el CUIT/DNI de cada comprador, para saber qué
/// facturar. Funciona igual que Historial: se puede ver por día,
/// semana, mes, o elegir cualquier rango de fechas.
class FacturacionScreen extends ConsumerWidget {
  const FacturacionScreen({super.key});

  Future<void> _elegirRangoPersonalizado(BuildContext context, WidgetRef ref) async {
    final filtros = ref.read(_filtrosFacturacionProvider);
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: filtros.desde, end: filtros.hasta),
    );
    if (rango != null) {
      ref.read(_filtrosFacturacionProvider.notifier).state = _FiltrosFacturacion(
        desde: rango.start,
        hasta: rango.end.add(const Duration(days: 1)),
      );
    }
  }

  void _elegirDia(WidgetRef ref) {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    ref.read(_filtrosFacturacionProvider.notifier).state =
        _FiltrosFacturacion(desde: inicio, hasta: inicio.add(const Duration(days: 1)));
  }

  void _elegirSemana(WidgetRef ref) {
    final hoy = DateTime.now();
    final inicioSemana = DateTime(hoy.year, hoy.month, hoy.day).subtract(Duration(days: hoy.weekday - 1));
    ref.read(_filtrosFacturacionProvider.notifier).state =
        _FiltrosFacturacion(desde: inicioSemana, hasta: inicioSemana.add(const Duration(days: 7)));
  }

  void _elegirMes(WidgetRef ref) {
    final hoy = DateTime.now();
    ref.read(_filtrosFacturacionProvider.notifier).state = _FiltrosFacturacion(
      desde: DateTime(hoy.year, hoy.month, 1),
      hasta: DateTime(hoy.year, hoy.month + 1, 1),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(_filtrosFacturacionProvider);
    final itemsAsync = ref.watch(_facturacionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Elegir rango de fechas',
            onPressed: () => _elegirRangoPersonalizado(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_facturacionProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(label: const Text('Hoy'), onPressed: () => _elegirDia(ref)),
                    ActionChip(label: const Text('Esta semana'), onPressed: () => _elegirSemana(ref)),
                    ActionChip(label: const Text('Este mes'), onPressed: () => _elegirMes(ref)),
                    ActionChip(
                        label: const Text('Rango personalizado'),
                        onPressed: () => _elegirRangoPersonalizado(context, ref)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${Formatters.formatearFecha(filtros.desde)} — '
                  '${Formatters.formatearFecha(filtros.hasta.subtract(const Duration(days: 1)))}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No hubo ventas por transferencia en este período.'));
                }
                final total = items.fold(0.0, (acc, i) => acc + i.montoTransferido);
                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total a facturar (${items.length} venta(s))',
                                style: TextStyle(color: Colors.grey.shade300)),
                            Text(
                              Formatters.formatearMoneda(total),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final v = item.venta;
                          return Card(
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
                                v.nombreCliente != null && v.nombreCliente!.isNotEmpty
                                    ? 'Venta #${v.numero} · ${v.nombreCliente}'
                                    : 'Venta #${v.numero}',
                              ),
                              subtitle: Text(
                                (v.cuitDniComprador != null && v.cuitDniComprador!.isNotEmpty
                                        ? 'CUIT/DNI: ${v.cuitDniComprador} · '
                                        : 'Sin CUIT/DNI cargado · ') +
                                    Formatters.formatearFechaHora(v.fecha),
                                style: TextStyle(
                                  color: (v.cuitDniComprador == null || v.cuitDniComprador!.isEmpty)
                                      ? Colors.orange.shade300
                                      : null,
                                ),
                              ),
                              trailing: Text(
                                Formatters.formatearMoneda(item.montoTransferido),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, __) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
