import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/stock.dart';

/// Un ítem del historial: puede ser "se creó este producto" o un
/// movimiento de stock real (ingreso, ajuste, merma).
class _ItemHistorial {
  final DateTime fecha;
  final String titulo;
  final String subtitulo;
  final String? productoIdParaBorrar; // si no-nulo: swipe borra el PRODUCTO
  final String? movimientoIdParaBorrar; // si no-nulo: swipe borra el MOVIMIENTO
  final Color color;
  final IconData icono;

  _ItemHistorial({
    required this.fecha,
    required this.titulo,
    required this.subtitulo,
    this.productoIdParaBorrar,
    this.movimientoIdParaBorrar,
    required this.color,
    required this.icono,
  });
}

final _historialStockProvider = FutureProvider.autoDispose<List<_ItemHistorial>>((ref) async {
  final productos = await ref.watch(productoRepositoryProvider).obtenerTodos();
  final movimientos = await ref.watch(stockRepositoryProvider).obtenerHistorialGlobal();
  final nombrePorProducto = {for (final p in productos) p.id: p.nombre};

  final items = <_ItemHistorial>[];

  for (final p in productos) {
    if (p.fechaCreacion == null) continue;
    items.add(_ItemHistorial(
      fecha: p.fechaCreacion!,
      titulo: 'Producto creado: ${p.nombre}',
      subtitulo: 'Costo inicial: ${Formatters.formatearMoneda(p.costoUnitario)}',
      productoIdParaBorrar: p.id,
      color: Colors.purple.shade700,
      icono: Icons.new_releases,
    ));
  }

  for (final m in movimientos) {
    // La venta ya se ve en el historial de Ventas; acá solo interesa lo
    // que alguien cargó/ajustó/perdió a mano.
    if (m.tipo == TipoMovimientoStock.ventaDescuento) continue;
    final nombreProducto = nombrePorProducto[m.productoId] ?? '(producto eliminado)';
    final (titulo, color, icono) = switch (m.tipo) {
      TipoMovimientoStock.ingreso => ('Ingreso de mercadería', Colors.blue.shade700, Icons.add_box),
      TipoMovimientoStock.merma => ('Merma', Colors.red.shade700, Icons.remove_circle),
      TipoMovimientoStock.ajusteManual => ('Ajuste manual', Colors.orange.shade700, Icons.tune),
      TipoMovimientoStock.ventaDescuento => ('', Colors.grey, Icons.help), // no llega acá (filtrado arriba)
    };
    items.add(_ItemHistorial(
      fecha: m.fecha,
      titulo: '$titulo: $nombreProducto',
      subtitulo: '${m.cantidad > 0 ? '+' : ''}${Formatters.formatearCantidad(m.cantidad)}'
          '${m.nota != null && m.nota!.isNotEmpty ? ' · ${m.nota}' : ''}',
      movimientoIdParaBorrar: m.id,
      color: color,
      icono: icono,
    ));
  }

  items.sort((a, b) => b.fecha.compareTo(a.fecha));
  return items;
});

/// Historial combinado de stock: cuándo se creó cada producto, y cuándo
/// se cargó/ajustó/perdió mercadería — para poder auditar todo el
/// movimiento del inventario en un solo lugar.
class HistorialStockScreen extends ConsumerWidget {
  const HistorialStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(_historialStockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Vaciar historial (no borra productos ni stock actual)',
            onPressed: () => _vaciarHistorial(context, ref, itemsAsync.valueOrNull ?? []),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_historialStockProvider),
          ),
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Todavía no hay movimientos de stock.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: ValueKey(item.productoIdParaBorrar ?? item.movimientoIdParaBorrar),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  final esProducto = item.productoIdParaBorrar != null;
                  return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(esProducto ? 'Eliminar producto' : 'Eliminar movimiento'),
                          content: Text(
                            esProducto
                                ? '¿Eliminar este producto del catálogo? Esta acción no se puede deshacer.'
                                : '¿Eliminar este movimiento del historial? Esto no revierte la cantidad de stock.',
                          ),
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
                  if (item.productoIdParaBorrar != null) {
                    await ref.read(gestionarProductosUseCaseProvider).eliminar(item.productoIdParaBorrar!);
                  } else if (item.movimientoIdParaBorrar != null) {
                    await ref.read(stockRepositoryProvider).eliminarMovimiento(item.movimientoIdParaBorrar!);
                  }
                  ref.invalidate(_historialStockProvider);
                },
                child: ListTile(
                  leading: Icon(item.icono, color: item.color),
                  title: Text(item.titulo),
                  subtitle: Text('${item.subtitulo} · ${Formatters.formatearFechaHora(item.fecha)}'),
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

Future<void> _vaciarHistorial(BuildContext context, WidgetRef ref, List<_ItemHistorial> items) async {
  final movimientos = items.where((i) => i.movimientoIdParaBorrar != null).toList();
  if (movimientos.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay movimientos para vaciar (los productos no se tocan).')),
    );
    return;
  }
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Vaciar historial'),
      content: Text(
        '¿Borrar los ${movimientos.length} registros de movimientos de este historial? '
        'Esto NO borra los productos ni cambia el stock actual, solo limpia el registro.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Vaciar'),
        ),
      ],
    ),
  );
  if (confirmado != true) return;

  for (final m in movimientos) {
    await ref.read(stockRepositoryProvider).eliminarMovimiento(m.movimientoIdParaBorrar!);
  }
  ref.invalidate(_historialStockProvider);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${movimientos.length} registros borrados.')),
    );
  }
}
