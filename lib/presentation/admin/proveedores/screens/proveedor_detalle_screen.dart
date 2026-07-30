import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/proveedor.dart';
import '../../../../domain/entities/producto.dart';

final _pedidosProveedorProvider =
    FutureProvider.autoDispose.family<List<PedidoProveedor>, String>((ref, proveedorId) async {
  final repo = ref.watch(proveedorRepositoryProvider);
  // Pedidos de TODOS los proveedores (para no pisar la cache local
  // entera con un refresh parcial); se filtra al de este proveedor.
  List<PedidoProveedor> todos;
  try {
    todos = await repo.obtenerTodosLosPedidosGlobal();
  } catch (_) {
    todos = await repo.obtenerPedidos(proveedorId);
  }
  return todos.where((p) => p.proveedorId == proveedorId).toList()
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
});

String _labelMetodo(MetodoPagoProveedor m) => switch (m) {
      MetodoPagoProveedor.efectivo => 'Efectivo',
      MetodoPagoProveedor.transferencia => 'Transferencia',
      MetodoPagoProveedor.cheque => 'Cheque',
    };

/// Detalle de un proveedor: historial de pedidos (producto, cantidad,
/// cómo se le pagó) y botón para cargar uno nuevo.
class ProveedorDetalleScreen extends ConsumerWidget {
  final Proveedor proveedor;
  const ProveedorDetalleScreen({super.key, required this.proveedor});

  Future<void> _nuevoPedido(BuildContext context, WidgetRef ref) async {
    final productos = await ref.read(productoRepositoryProvider).obtenerTodos();
    Producto? productoSeleccionado;
    final productoLibreCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    MetodoPagoProveedor metodo = MetodoPagoProveedor.efectivo;
    bool usarProductoLibre = productos.isEmpty;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo pedido'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (productos.isNotEmpty) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Del catálogo')),
                      ButtonSegment(value: true, label: Text('Otro producto')),
                    ],
                    selected: {usarProductoLibre},
                    onSelectionChanged: (s) => setDialogState(() => usarProductoLibre = s.first),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!usarProductoLibre && productos.isNotEmpty)
                  DropdownButtonFormField<Producto>(
                    initialValue: productoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Producto', border: OutlineInputBorder()),
                    items: productos
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.nombre)))
                        .toList(),
                    onChanged: (p) => setDialogState(() => productoSeleccionado = p),
                  )
                else
                  TextField(
                    controller: productoLibreCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Producto (texto libre)', border: OutlineInputBorder()),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cantidad pedida', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto pagado', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('¿Cómo se le abonó?', style: TextStyle(color: Colors.grey.shade400)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: MetodoPagoProveedor.values.map((m) {
                    return ChoiceChip(
                      label: Text(_labelMetodo(m)),
                      selected: metodo == m,
                      onSelected: (_) => setDialogState(() => metodo = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notaCtrl,
                  decoration: const InputDecoration(labelText: 'Nota (opcional)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (confirmado != true) return;

    final cantidad = double.tryParse(cantidadCtrl.text.replaceAll(',', '.'));
    final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.'));
    final nombreProducto = usarProductoLibre || productoSeleccionado == null
        ? productoLibreCtrl.text.trim()
        : productoSeleccionado!.nombre;
    if (cantidad == null || cantidad <= 0 || monto == null || monto < 0 || nombreProducto.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completá producto, cantidad y monto correctamente')),
        );
      }
      return;
    }

    final usuarioId = ref.read(currentUserIdProvider);
    await ref.read(proveedorRepositoryProvider).registrarPedido(PedidoProveedor(
          id: const Uuid().v4(),
          proveedorId: proveedor.id,
          productoId: usarProductoLibre ? null : productoSeleccionado?.id,
          productoNombre: nombreProducto,
          cantidad: cantidad,
          metodoPago: metodo,
          monto: monto,
          fecha: DateTime.now(),
          usuarioId: usuarioId,
          nota: notaCtrl.text.trim().isEmpty ? null : notaCtrl.text.trim(),
        ));
    ref.invalidate(_pedidosProveedorProvider(proveedor.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosAsync = ref.watch(_pedidosProveedorProvider(proveedor.id));

    return Scaffold(
      appBar: AppBar(title: Text(proveedor.nombre)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevoPedido(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo pedido'),
      ),
      body: pedidosAsync.when(
        data: (pedidos) {
          if (pedidos.isEmpty) {
            return const Center(child: Text('Todavía no hay pedidos cargados a este proveedor.'));
          }
          return ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (context, i) {
              final p = pedidos[i];
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
                          title: const Text('Eliminar pedido'),
                          content: const Text('¿Borrar este pedido del historial del proveedor?'),
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
                  await ref.read(proveedorRepositoryProvider).eliminarPedido(p.id);
                  ref.invalidate(_pedidosProveedorProvider(proveedor.id));
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.shopping_bag_rounded,
                          size: 20, color: Theme.of(context).colorScheme.secondary),
                    ),
                    title: Text('${p.productoNombre} · ${Formatters.formatearCantidad(p.cantidad)}'),
                    subtitle: Text(
                      '${_labelMetodo(p.metodoPago)} · ${Formatters.formatearFechaHora(p.fecha)}'
                      '${p.nota != null && p.nota!.isNotEmpty ? ' · ${p.nota}' : ''}',
                    ),
                    trailing: Text(
                      Formatters.formatearMoneda(p.monto),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
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
