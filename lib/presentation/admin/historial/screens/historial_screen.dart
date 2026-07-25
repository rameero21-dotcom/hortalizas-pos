import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/venta.dart';

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
    return matchNumero || matchProducto || matchVendedor;
  }).toList();
});

/// Búsqueda de ventas cobradas por fecha, número, producto o vendedor.
class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(_filtrosProvider);
    final ventasAsync = ref.watch(_ventasHistorialProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ventas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar por número, producto o vendedor',
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
            child: ventasAsync.when(
              data: (ventas) {
                if (ventas.isEmpty) {
                  return const Center(child: Text('No hay ventas cobradas en este rango.'));
                }
                return ListView.builder(
                  itemCount: ventas.length,
                  itemBuilder: (context, index) {
                    final venta = ventas[index];
                    return ListTile(
                      title: Text('Venta #${venta.numero}'),
                      subtitle: Text(
                          '${Formatters.formatearFechaHora(venta.fecha)} · ${venta.detalle.length} producto(s)'),
                      trailing: Text(
                        Formatters.formatearMoneda(venta.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => showModalBottomSheet(
                        context: context,
                        builder: (_) => _DetalleVentaHistorial(venta: venta),
                      ),
                    );
                  },
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
                  subtitle: Text('Cantidad: ${d.cantidad}'),
                  trailing: Text(Formatters.formatearMoneda(d.precioTotal)),
                )),
            const Divider(),
            Text('Total: ${Formatters.formatearMoneda(venta.total)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (venta.metodoPago != null) Text('Pago: ${venta.metodoPago!.name}'),
          ],
        ),
      ),
    );
  }
}
