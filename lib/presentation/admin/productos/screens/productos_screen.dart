import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/producto.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/loading_widget.dart';
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
      appBar: GradientAppBar(
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
                  EmptyState(
                    icon: Icons.eco_outlined,
                    message: 'No hay productos cargados todavía. Tocá + para agregar uno.',
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
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: p.activo ? _colorCategoria(p.categoria) : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
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
                )
                    // Entrada escalonada por fila (tope en 12 para que una
                    // lista larga no tarde segundos en terminar de aparecer).
                    .animate(delay: (index.clamp(0, 12) * 40).ms)
                    .fadeIn(duration: 220.ms)
                    .slideX(begin: 0.04, end: 0, duration: 220.ms, curve: Curves.easeOut);
              },
            );
          },
          loading: () => const LoadingWidget(),
          error: (err, __) => Center(child: Text('Error al cargar productos: $err')),
        ),
      ),
    );
  }
}

/// Asigna a cada categoría un color estable (siempre el mismo para la
/// misma categoría) tomado de una paleta reducida, para que el punto de
/// color funcione como una referencia visual rápida al recorrer la lista.
Color _colorCategoria(String categoria) {
  const paleta = [
    Color(0xFFC0392B),
    Color(0xFF2F7D5A),
    Color(0xFF1226A9),
    Color(0xFFFE9015),
    Color(0xFF6E4E9E),
    Color(0xFF1B7A8C),
  ];
  return paleta[categoria.hashCode.abs() % paleta.length];
}
