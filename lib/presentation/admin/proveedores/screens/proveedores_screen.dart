import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import 'proveedor_form_screen.dart';
import 'proveedor_detalle_screen.dart';

final proveedoresListProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(proveedorRepositoryProvider);
  try {
    await repo.refrescarDesdeRemoto();
  } catch (_) {
    // Sin conexión: seguimos con la caché local.
  }
  final proveedores = await repo.obtenerTodos();
  proveedores.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  return proveedores;
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
          return ListView.builder(
            itemCount: proveedores.length,
            itemBuilder: (context, index) {
              final p = proveedores[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.local_shipping_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(p.nombre),
                  subtitle: Text(p.telefono.isEmpty ? 'Sin teléfono cargado' : p.telefono),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProveedorFormScreen(proveedor: p)),
                      );
                      ref.invalidate(proveedoresListProvider);
                    },
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProveedorDetalleScreen(proveedor: p)),
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
