import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/producto.dart';
import '../../../../domain/entities/stock.dart';
import 'ingreso_mercaderia_screen.dart';
import 'ajuste_stock_screen.dart';
import 'registrar_merma_screen.dart';

class _ProductoConStock {
  final Producto producto;
  final Stock? stock;
  _ProductoConStock(this.producto, this.stock);
}

/// Junta productos + su fila de stock para mostrar todo en una sola lista.
final stockConProductosProvider = FutureProvider.autoDispose<List<_ProductoConStock>>((ref) async {
  final productos = await ref.watch(productoRepositoryProvider).obtenerTodos();
  final stocks = await ref.watch(stockRepositoryProvider).obtenerTodos();
  final stockPorProducto = {for (final s in stocks) s.productoId: s};
  return productos.map((p) => _ProductoConStock(p, stockPorProducto[p.id])).toList();
});

/// Listado de stock por producto con indicador de stock bajo,
/// accesos a ingreso de mercadería, ajuste manual e historial.
class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(stockConProductosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () async {
              await ref.read(productoRepositoryProvider).refrescarDesdeRemoto();
              await ref.read(stockRepositoryProvider).refrescarDesdeRemoto();
              ref.invalidate(stockConProductosProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(productoRepositoryProvider).refrescarDesdeRemoto();
          await ref.read(stockRepositoryProvider).refrescarDesdeRemoto();
          ref.invalidate(stockConProductosProvider);
        },
        child: stockAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay productos cargados. Cargalos primero en Admin > Productos.'),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final stock = item.stock;
                final cantidad = stock?.cantidadDisponible ?? 0;
                final stockNegativo = cantidad < 0;
                final stockBajo = stock?.stockBajo ?? true;
                return ListTile(
                  leading: stockNegativo
                      ? const Icon(Icons.error, color: Colors.red)
                      : stockBajo
                          ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
                          : const Icon(Icons.check_circle_outline, color: Colors.green),
                  title: Text(item.producto.nombre),
                  subtitle: Text(
                    stockNegativo
                        ? 'Stock negativo — revisar (¿venta sin stock cargado?)'
                        : stockBajo
                            ? 'Stock bajo'
                            : 'Stock OK',
                  ),
                  trailing: Text(
                    Formatters.formatearCantidad(cantidad),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: stockNegativo ? Colors.red : null,
                    ),
                  ),
                  onTap: () => _mostrarAcciones(context, ref, item),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, __) => Center(child: Text('Error al cargar stock: $err')),
        ),
      ),
    );
  }

  void _mostrarAcciones(BuildContext context, WidgetRef ref, _ProductoConStock item) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Stock actual: ${Formatters.formatearCantidad(item.stock?.cantidadDisponible ?? 0)}'),
            ),
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text('Ingresar mercadería'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => IngresoMercaderiaScreen(producto: item.producto)),
                );
                ref.invalidate(stockConProductosProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Ajuste manual'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AjusteStockScreen(
                            producto: item.producto,
                            cantidadActual: item.stock?.cantidadDisponible ?? 0,
                          )),
                );
                ref.invalidate(stockConProductosProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('Registrar merma'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegistrarMermaScreen(producto: item.producto)),
                );
                ref.invalidate(stockConProductosProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}
