import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import 'proveedor_form_screen.dart';
import 'proveedor_detalle_screen.dart';

/// Escucha en tiempo real: un proveedor creado/editado desde CUALQUIER
/// dispositivo aparece acá sin necesitar refrescar manualmente.
final proveedoresListProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(proveedorRepositoryProvider).observarTodos().map((proveedores) {
    final ordenados = List.of(proveedores);
    ordenados.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return ordenados;
  });
});

/// Listado de proveedores: de quién se compra mercadería. Cada uno
/// tiene su propio historial de pedidos (producto, cantidad, forma de
/// pago) accesible tocando la tarjeta.
class ProveedoresScreen extends ConsumerWidget {
  const ProveedoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proveedoresAsync = ref.watch(proveedoresListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProveedorFormScreen()),
          );
          ref.invalidate(proveedoresListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: proveedoresAsync.when(
        data: (proveedores) {
          if (proveedores.isEmpty) {
            return const Center(child: Text('No hay proveedores cargados. Tocá + para agregar uno.'));
          }
          final totalQueLesDebemos = proveedores
              .where((p) => p.saldoCuentaCorriente > 0)
              .fold(0.0, (acc, p) => acc + p.saldoCuentaCorriente);
          return Column(
            children: [
              if (totalQueLesDebemos > 0)
                Card(
                  margin: const EdgeInsets.all(12),
                  color: Colors.red.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total que les debemos a los proveedores'),
                        Text(
                          Formatters.formatearMoneda(totalQueLesDebemos),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade300),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: proveedores.length,
                  itemBuilder: (context, index) {
                    final p = proveedores[index];
                    return Dismissible(
                      key: ValueKey(p.id),
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
                                title: const Text('Eliminar proveedor'),
                                content: Text(
                                  p.saldoCuentaCorriente != 0
                                      ? '¿Eliminar a ${p.nombre}? Todavía hay un saldo de '
                                          '${Formatters.formatearMoneda(p.saldoCuentaCorriente)} en su cuenta. '
                                          'Esta acción no se puede deshacer.'
                                      : '¿Eliminar a ${p.nombre}? Esta acción no se puede deshacer.',
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
                        await ref.read(proveedorRepositoryProvider).eliminar(p.id);
                        ref.invalidate(proveedoresListProvider);
                      },
                      child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.local_shipping_rounded,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(p.nombre),
                        subtitle: Text(p.telefono.isEmpty ? 'Sin teléfono cargado' : p.telefono),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p.saldoCuentaCorriente != 0)
                              Text(
                                Formatters.formatearMoneda(p.saldoCuentaCorriente.abs()),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: p.saldoCuentaCorriente > 0 ? Colors.red : Colors.green,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProveedorFormScreen(proveedor: p)),
                                );
                                ref.invalidate(proveedoresListProvider);
                              },
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProveedorDetalleScreen(proveedor: p)),
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
    );
  }
}
