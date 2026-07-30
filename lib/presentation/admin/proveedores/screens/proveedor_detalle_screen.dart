import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/proveedor.dart';
import '../../../../domain/entities/producto.dart';

/// Un ítem del historial combinado: puede ser un pedido (suma al saldo)
/// o un pago (resta del saldo).
class _ItemHistorialProveedor {
  final DateTime fecha;
  final String titulo;
  final String subtitulo;
  final double monto;
  final bool esPedido; // true = pedido (suma), false = pago (resta)
  final String idParaBorrar;

  _ItemHistorialProveedor({
    required this.fecha,
    required this.titulo,
    required this.subtitulo,
    required this.monto,
    required this.esPedido,
    required this.idParaBorrar,
  });
}

final _historialProveedorProvider =
    FutureProvider.autoDispose.family<List<_ItemHistorialProveedor>, String>((ref, proveedorId) async {
  final repo = ref.watch(proveedorRepositoryProvider);

  List<PedidoProveedor> pedidos;
  List<PagoProveedor> pagos;
  try {
    final todosPedidos = await repo.obtenerTodosLosPedidosGlobal();
    pedidos = todosPedidos.where((p) => p.proveedorId == proveedorId).toList();
  } catch (_) {
    pedidos = await repo.obtenerPedidos(proveedorId);
  }
  try {
    final todosPagos = await repo.obtenerTodosLosPagosGlobal();
    pagos = todosPagos.where((p) => p.proveedorId == proveedorId).toList();
  } catch (_) {
    pagos = await repo.obtenerPagos(proveedorId);
  }

  final items = <_ItemHistorialProveedor>[
    for (final p in pedidos)
      _ItemHistorialProveedor(
        fecha: p.fecha,
        titulo: '${p.productoNombre} · ${Formatters.formatearCantidad(p.cantidad)}',
        subtitulo: 'Pedido · ${_labelMetodo(p.metodoPago)}${p.nota != null && p.nota!.isNotEmpty ? ' · ${p.nota}' : ''}',
        monto: p.monto,
        esPedido: true,
        idParaBorrar: p.id,
      ),
    for (final p in pagos)
      _ItemHistorialProveedor(
        fecha: p.fecha,
        titulo: 'Pago',
        subtitulo: _labelMetodo(p.metodoPago) + (p.nota != null && p.nota!.isNotEmpty ? ' · ${p.nota}' : ''),
        monto: p.monto,
        esPedido: false,
        idParaBorrar: p.id,
      ),
  ];
  items.sort((a, b) => b.fecha.compareTo(a.fecha));
  return items;
});

String _labelMetodo(MetodoPagoProveedor m) => switch (m) {
      MetodoPagoProveedor.efectivo => 'Efectivo',
      MetodoPagoProveedor.transferencia => 'Transferencia',
      MetodoPagoProveedor.cheque => 'Cheque',
    };

/// Detalle de un proveedor: saldo de cuenta corriente (positivo = le
/// debemos), historial combinado de pedidos (suman) y pagos (restan).
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
                Text(
                  'Esto suma el monto a lo que le debemos al proveedor.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 12),
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
                  decoration: const InputDecoration(labelText: 'Monto del pedido', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('¿Cómo se piensa abonar?', style: TextStyle(color: Colors.grey.shade400)),
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
    ref.invalidate(_historialProveedorProvider(proveedor.id));
  }

  Future<void> _registrarPago(BuildContext context, WidgetRef ref) async {
    final montoCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    MetodoPagoProveedor metodo = MetodoPagoProveedor.efectivo;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar pago al proveedor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esto resta el monto de lo que le debemos.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto pagado', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('¿Cómo se pagó?', style: TextStyle(color: Colors.grey.shade400)),
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (confirmado != true) return;
    final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresá un monto válido')),
        );
      }
      return;
    }

    final usuarioId = ref.read(currentUserIdProvider);
    await ref.read(proveedorRepositoryProvider).registrarPago(PagoProveedor(
          id: const Uuid().v4(),
          proveedorId: proveedor.id,
          monto: monto,
          metodoPago: metodo,
          fecha: DateTime.now(),
          usuarioId: usuarioId,
          nota: notaCtrl.text.trim().isEmpty ? null : notaCtrl.text.trim(),
        ));
    ref.invalidate(_historialProveedorProvider(proveedor.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(_historialProveedorProvider(proveedor.id));

    // Ojo con el signo: acá POSITIVO significa que le debemos al
    // proveedor (al revés que en clientes, donde negativo es lo que
    // nos deben a nosotros).
    final leDebemos = proveedor.saldoCuentaCorriente > 0;

    return Scaffold(
      appBar: AppBar(title: Text(proveedor.nombre)),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            color: (leDebemos ? Colors.red : Colors.green).withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: leDebemos ? Colors.red : Colors.green),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Saldo con el proveedor', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.formatearMoneda(proveedor.saldoCuentaCorriente.abs()),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: leDebemos ? Colors.red.shade300 : Colors.green.shade300,
                    ),
                  ),
                  Text(leDebemos ? 'Le debemos' : 'Estamos al día', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _nuevoPedido(context, ref),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Nuevo pedido'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _registrarPago(context, ref),
                    icon: const Icon(Icons.check),
                    label: const Text('Registrar pago'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: historialAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('Todavía no hay movimientos con este proveedor.'));
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final color = item.esPedido ? Colors.red.shade300 : Colors.green.shade300;
                    return Dismissible(
                      key: ValueKey(item.idParaBorrar),
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
                                title: Text(item.esPedido ? 'Eliminar pedido' : 'Eliminar pago'),
                                content: const Text(
                                    '¿Eliminar este movimiento? El saldo del proveedor se va a recalcular.'),
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
                        final repo = ref.read(proveedorRepositoryProvider);
                        if (item.esPedido) {
                          await repo.eliminarPedido(item.idParaBorrar);
                        } else {
                          await repo.eliminarPago(item.idParaBorrar);
                        }
                        ref.invalidate(_historialProveedorProvider(proveedor.id));
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.esPedido ? Icons.shopping_bag_rounded : Icons.check_circle_outline,
                              size: 20,
                              color: color,
                            ),
                          ),
                          title: Text(item.titulo),
                          subtitle: Text('${item.subtitulo} · ${Formatters.formatearFechaHora(item.fecha)}'),
                          trailing: Text(
                            '${item.esPedido ? '+' : '-'}${Formatters.formatearMoneda(item.monto)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: color),
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
          ),
        ],
      ),
    );
  }
}
