import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import 'cliente_form_screen.dart';

final clientesListProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(clienteRepositoryProvider).obtenerTodos();
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
                trailing: c.saldoCuentaCorriente != 0
                    ? Text(
                        Formatters.formatearMoneda(c.saldoCuentaCorriente),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: c.saldoCuentaCorriente < 0 ? Colors.red : Colors.green,
                        ),
                      )
                    : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: c)),
                  );
                  ref.invalidate(clientesListProvider);
                },
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
