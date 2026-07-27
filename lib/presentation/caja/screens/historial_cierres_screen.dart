import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/caja.dart';

final _cierresProvider = FutureProvider.autoDispose<List<CierreCaja>>((ref) async {
  final ahora = DateTime.now();
  // Últimos 30 días, para ver cierres de días anteriores también.
  final desde = ahora.subtract(const Duration(days: 30));
  return ref.watch(cajaRepositoryProvider).obtenerCierres(desde, ahora.add(const Duration(days: 1)));
});

/// Lista los cierres de caja ya guardados, para poder confirmar que un
/// cierre efectivamente se guardó (y consultar cierres de días anteriores).
class HistorialCierresScreen extends ConsumerWidget {
  const HistorialCierresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cierresAsync = ref.watch(_cierresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierres de caja guardados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_cierresProvider),
          ),
        ],
      ),
      body: cierresAsync.when(
        data: (cierres) {
          if (cierres.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay ningún cierre guardado en los últimos 30 días.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: cierres.length,
            itemBuilder: (context, index) {
              final c = cierres[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  title: Text(Formatters.formatearFechaHora(c.fecha)),
                  subtitle: Text('Total contado: ${Formatters.formatearMoneda(c.totalContado)}'),
                  children: [
                    ListTile(
                      dense: true,
                      title: const Text('Caja inicio'),
                      trailing: Text(Formatters.formatearMoneda(c.cajaInicio)),
                    ),
                    const Divider(),
                    ...c.billetes.map((b) => ListTile(
                          dense: true,
                          title: Text(Formatters.formatearMoneda(b.denominacion)),
                          trailing: Text('x${b.cantidad} = ${Formatters.formatearMoneda(b.subtotal)}'),
                        )),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
