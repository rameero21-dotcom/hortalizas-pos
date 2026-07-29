import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';

/// Cuántos cambios locales todavía no llegaron a Firestore. Se
/// refresca solo cada 5 segundos mientras la pantalla esté abierta,
/// para detectar si algo quedó trabado (sin conexión, o un error
/// persistente) sin que el usuario tenga que hacer nada.
final pendientesSincronizacionProvider = StreamProvider.autoDispose<int>((ref) async* {
  final syncQueue = ref.watch(syncQueueLocalDsProvider);
  while (true) {
    yield await syncQueue.contarPendientes();
    await Future.delayed(const Duration(seconds: 5));
  }
});

/// Ícono pequeño con un número que aparece SOLO si hay cambios sin
/// sincronizar todavía (ventas, stock, etc. que se hicieron en este
/// dispositivo pero no llegaron a la nube). Si está en 0, no muestra
/// nada — no le agrega ruido visual a la pantalla en el uso normal.
class IndicadorSincronizacion extends ConsumerWidget {
  const IndicadorSincronizacion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientesAsync = ref.watch(pendientesSincronizacionProvider);
    final pendientes = pendientesAsync.valueOrNull ?? 0;
    if (pendientes == 0) return const SizedBox.shrink();

    return IconButton(
      icon: Badge(
        label: Text('$pendientes'),
        child: const Icon(Icons.cloud_off, color: Colors.orange),
      ),
      tooltip: '$pendientes cambio(s) todavía sin subir a la nube. '
          'Revisá que el dispositivo tenga internet.',
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hay $pendientes cambio(s) hechos en este dispositivo que '
              'todavía no se subieron a la nube (revisá la conexión a internet). '
              'Se van a subir solos apenas haya señal.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      },
    );
  }
}
