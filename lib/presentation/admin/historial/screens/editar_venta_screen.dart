import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/venta.dart';
import '../../../../domain/entities/detalle_venta.dart';
import '../../../../domain/entities/producto.dart';

/// Pantalla para editar el detalle de una venta ya realizada (agregar
/// un producto, sacar uno, cambiar cantidad/precio). Si la venta ya
/// estaba cobrada, el caso de uso reconcilia el stock y la cuenta
/// corriente por la diferencia — acá solo se arma la lista nueva.
class EditarVentaScreen extends ConsumerStatefulWidget {
  final Venta venta;
  const EditarVentaScreen({super.key, required this.venta});

  @override
  ConsumerState<EditarVentaScreen> createState() => _EditarVentaScreenState();
}

class _EditarVentaScreenState extends ConsumerState<EditarVentaScreen> {
  late List<DetalleVenta> _items;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.venta.detalle);
  }

  double get _total => _items.fold(0, (acc, d) => acc + d.precioTotal);

  Future<void> _agregarOEditarItem({DetalleVenta? existente}) async {
    final productos = await ref.read(productoRepositoryProvider).obtenerTodos();
    Producto? productoSeleccionado;
    final productoLibreNombre = existente?.nombreProducto;
    final cantidadCtrl =
        TextEditingController(text: existente != null ? Formatters.formatearCantidad(existente.cantidad) : '');
    final precioCtrl = TextEditingController(
        text: existente != null && existente.cantidad > 0
            ? (existente.precioTotal / existente.cantidad).toStringAsFixed(0)
            : '');

    final resultado = await showDialog<DetalleVenta>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cantidad = double.tryParse(cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
          final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;
          final totalItem = cantidad * precio;
          return AlertDialog(
            title: Text(existente != null ? 'Editar producto' : 'Agregar producto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existente == null)
                    DropdownButtonFormField<Producto>(
                      initialValue: productoSeleccionado,
                      decoration:
                          const InputDecoration(labelText: 'Producto', border: OutlineInputBorder()),
                      items: productos.map((p) => DropdownMenuItem(value: p, child: Text(p.nombre))).toList(),
                      onChanged: (p) => setDialogState(() => productoSeleccionado = p),
                    )
                  else
                    Text(productoLibreNombre ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: precioCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Precio por unidad', border: OutlineInputBorder()),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.secondary),
                    ),
                    child: Text(
                      'Total: ${Formatters.formatearMoneda(totalItem)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final cant = double.tryParse(cantidadCtrl.text.replaceAll(',', '.'));
                  final prec = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
                  final nombreFinal = existente?.nombreProducto ?? productoSeleccionado?.nombre;
                  final idFinal = existente?.productoId ?? productoSeleccionado?.id;
                  if (cant == null || cant <= 0 || prec == null || prec < 0 || nombreFinal == null || idFinal == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Completá producto, cantidad y precio correctamente')),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    DetalleVenta(
                      productoId: idFinal,
                      nombreProducto: nombreFinal,
                      cantidad: cant,
                      precioTotal: cant * prec,
                    ),
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (resultado == null) return;
    setState(() {
      if (existente != null) {
        final idx = _items.indexOf(existente);
        if (idx != -1) _items[idx] = resultado;
      } else {
        _items.add(resultado);
      }
    });
  }

  void _quitarItem(DetalleVenta item) {
    setState(() => _items.remove(item));
  }

  Future<void> _guardar() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La venta tiene que tener al menos un producto')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final usuarioId = ref.read(currentUserIdProvider);
      await ref.read(editarVentaUseCaseProvider).call(widget.venta, _items, usuarioId);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar venta #${widget.venta.numero}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _agregarOEditarItem(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (widget.venta.estado == EstadoVenta.cobrada)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Esta venta ya está cobrada: el stock y la cuenta corriente (si era fiada) '
                'se van a ajustar automáticamente por la diferencia.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade300),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Text(item.nombreProducto),
                    subtitle: Text('Cantidad: ${Formatters.formatearCantidad(item.cantidad)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Formatters.formatearMoneda(item.precioTotal)),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _agregarOEditarItem(existente: item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _quitarItem(item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(
                      Formatters.formatearMoneda(_total),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
