import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/producto.dart';
import 'producto_form_screen.dart';

/// Escucha en tiempo real: un producto creado/editado desde CUALQUIER
/// dispositivo aparece acá sin necesitar refrescar manualmente.
final productosListProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(productoRepositoryProvider).observarTodos().map((productos) {
    final ordenados = List.of(productos);
    ordenados.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return ordenados;
  });
});

/// Administración de productos: listar, buscar, activar/desactivar,
/// y navegar a producto_form_screen para crear/editar.
class ProductosScreen extends ConsumerWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productosAsync = ref.watch(productosListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () async {
              await ref.read(productoRepositoryProvider).refrescarDesdeRemoto();
              ref.invalidate(productosListProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductoFormScreen()),
          );
          ref.invalidate(productosListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(productoRepositoryProvider).refrescarDesdeRemoto();
          ref.invalidate(productosListProvider);
        },
        child: productosAsync.when(
          data: (productos) {
            if (productos.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay productos cargados todavía. Tocá + para agregar uno.'),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: productos.length,
              itemBuilder: (context, index) {
                final Producto p = productos[index];
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
                            title: const Text('Eliminar producto'),
                            content: Text('¿Eliminar "${p.nombre}" del catálogo? Esta acción no se puede deshacer.'),
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
                    await ref.read(gestionarProductosUseCaseProvider).eliminar(p.id);
                    ref.invalidate(productosListProvider);
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (p.activo ? Theme.of(context).colorScheme.secondary : Colors.grey)
                              .withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.eco_rounded,
                            color: p.activo ? Theme.of(context).colorScheme.secondary : Colors.grey),
                      ),
                      title: Text(
                        p.nombre,
                        style: TextStyle(
                          decoration: p.activo ? null : TextDecoration.lineThrough,
                          color: p.activo ? null : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        p.costoUnitario > 0
                            ? '${p.categoria} · Costo: ${Formatters.formatearMoneda(p.costoUnitario)}'
                            : p.categoria,
                      ),
                      trailing: Switch(
                        value: p.activo,
                        onChanged: (activo) async {
                          await ref.read(gestionarProductosUseCaseProvider).activarDesactivar(p, activo);
                          ref.invalidate(productosListProvider);
                        },
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: p)),
                        );
                        ref.invalidate(productosListProvider);
                      },
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, __) => Center(child: Text('Error al cargar productos: $err')),
        ),
      ),
    );
  }
}
