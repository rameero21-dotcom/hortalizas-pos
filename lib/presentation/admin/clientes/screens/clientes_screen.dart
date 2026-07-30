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
              return Dismissible(
                key: ValueKey(c.id),
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
                          title: const Text('Eliminar cliente'),
                          content: Text(
                            c.saldoCuentaCorriente != 0
                                ? '¿Eliminar a ${c.nombre}? Todavía tiene un saldo de '
                                    '${Formatters.formatearMoneda(c.saldoCuentaCorriente)} en cuenta corriente. '
                                    'Esta acción no se puede deshacer.'
                                : '¿Eliminar a ${c.nombre}? Esta acción no se puede deshacer.',
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar')),
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
                  await ref.read(clienteRepositoryProvider).eliminar(c.id);
                  ref.invalidate(clientesListProvider);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?'),
                    ),
                    title: Text(c.nombre),
                    subtitle: Text(
                      c.cuitODni.isNotEmpty
                          ? 'CUIT/DNI: ${c.cuitODni}'
                          : (c.telefono.isEmpty ? c.direccion : '${c.telefono} · ${c.direccion}'),
                    ),
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
                  ),
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
