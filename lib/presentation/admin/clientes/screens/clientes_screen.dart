import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import 'cliente_form_screen.dart';
import 'cliente_detalle_screen.dart';

final clientesListProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(clienteRepositoryProvider);
  try {
    await repo.refrescarDesdeRemoto();
  } catch (_) {
    // Sin conexión: seguimos con la caché local.
  }
  final clientes = await repo.obtenerTodos();
  clientes.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  return clientes;
});

/// Listado de clientes (preparado para el futuro): nombre, teléfono,
/// dirección, cuenta corriente, saldo.
class ClientesScreen extends ConsumerWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClienteFormScreen()),
          );
          ref.invalidate(clientesListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: clientesAsync.when(
        data: (clientes) {
          if (clientes.isEmpty) {
            return const Center(child: Text('No hay clientes cargados. Tocá + para agregar uno.'));
          }
          return ListView.builder(
            itemCount: clientes.length,
            itemBuilder: (context, index) {
              final c = clientes[index];
              return ListTile(
                title: Text(c.nombre),
                subtitle: Text(c.telefono.isEmpty ? c.direccion : '${c.telefono} · ${c.direccion}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.saldoCuentaCorriente != 0)
                      Text(
                        Formatters.formatearMoneda(c.saldoCuentaCorriente),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: c.saldoCuentaCorriente < 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: c)),
                        );
                        ref.invalidate(clientesListProvider);
                      },
                    ),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ClienteDetalleScreen(cliente: c)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
