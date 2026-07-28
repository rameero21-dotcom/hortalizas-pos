import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/producto.dart';
import 'producto_form_screen.dart';

/// Recarga la lista de productos. Se invalida manualmente después de
/// crear/editar/eliminar (no hay stream local de productos todavía).
final productosListProvider = FutureProvider.autoDispose((ref) async {
  final productos = await ref.watch(productoRepositoryProvider).obtenerTodos();
  productos.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  return productos;
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
                  child: ListTile(
                    title: Text(
                      p.nombre,
                      style: TextStyle(
                        decoration: p.activo ? null : TextDecoration.lineThrough,
                        color: p.activo ? null : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      p.precioSugerido > 0
                          ? '${p.categoria} · Sugerido: ${Formatters.formatearMoneda(p.precioSugerido)}'
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
