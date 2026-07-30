import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/detalle_venta.dart';
import '../../../domain/entities/venta.dart';
import '../providers/carrito_provider.dart';
import '../widgets/producto_search_field.dart';
import '../widgets/item_carrito_tile.dart';
import '../../shared/utils/cerrar_sesion.dart';
import '../../shared/widgets/indicador_sincronizacion.dart';

final _uuid = Uuid();

/// Pantalla principal del vendedor: buscar producto, ingresar cantidad
/// y precio (total o por unidad), agregar al carrito, y finalizar la
/// venta. Al finalizar, la venta se envía a caja y se muestra el QR en
/// pantalla como respaldo para escanear manualmente (útil para probar
/// sin lector físico, o si la sincronización automática tarda).
class NuevaVentaScreen extends ConsumerWidget {
  const NuevaVentaScreen({super.key});

  Future<void> _actualizar(WidgetRef ref) async {
    // Fuerza a releer productos/stock desde Firestore y refrescar la
    // caché local, para que los cambios hechos desde otro dispositivo
    // (ej. Admin agregó/repuso stock) se vean sin esperar.
    await ref.read(productoRepositoryProvider).refrescarDesdeRemoto();
  }

  Future<void> _editarItem(BuildContext context, WidgetRef ref, int index, DetalleVenta item) async {
    final cantidadCtrl = TextEditingController(text: Formatters.formatearCantidad(item.cantidad));
    final precioCtrl = TextEditingController(text: item.precioTotal.toStringAsFixed(0));

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar ${item.nombreProducto}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cantidadCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: precioCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio total', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (confirmado != true) return;
    final cantidad = double.tryParse(cantidadCtrl.text.replaceAll(',', '.'));
    final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0 || precio == null || precio <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cantidad y precio tienen que ser mayores a cero')),
        );
      }
      return;
    }

    ref.read(carritoProvider.notifier).editarProducto(
          index,
          DetalleVenta(
            productoId: item.productoId,
            nombreProducto: item.nombreProducto,
            cantidad: cantidad,
            precioTotal: precio,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    final total = ref.watch(carritoProvider.notifier).total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva venta'),
        actions: [
          const IndicadorSincronizacion(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar productos y stock',
            onPressed: () async {
              await _actualizar(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Productos y stock actualizados'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cambiar de usuario',
            onPressed: () => cerrarSesionYVolver(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _actualizar(ref),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: ProductoSearchField(),
            ),
            Expanded(
              child: carrito.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: Text('Agregá productos a la venta')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: carrito.length,
                      itemBuilder: (context, index) => ItemCarritoTile(
                        item: carrito[index],
                        onEliminar: () =>
                            ref.read(carritoProvider.notifier).eliminarProducto(index),
                        onEditar: () => _editarItem(context, ref, index, carrito[index]),
                      ),
                    ),
            ),
            _ResumenTotalYFinalizar(total: total),
          ],
        ),
      ),
    );
  }
}

class _ResumenTotalYFinalizar extends ConsumerStatefulWidget {
  final double total;
  const _ResumenTotalYFinalizar({required this.total});

  @override
  ConsumerState<_ResumenTotalYFinalizar> createState() => _ResumenTotalYFinalizarState();
}

class _ResumenTotalYFinalizarState extends ConsumerState<_ResumenTotalYFinalizar> {
  final _nombreClienteCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombreClienteCtrl.dispose();
    super.dispose();
  }

  Future<void> _finalizarVenta() async {
    final carritoNotifier = ref.read(carritoProvider.notifier);
    final detalle = ref.read(carritoProvider);
    if (detalle.isEmpty) return;

    setState(() => _guardando = true);
    try {
      final vendedorId = ref.read(currentUserIdProvider);
      final usuarioActual = await ref.read(usuarioRepositoryProvider).usuarioActual();
      final nombreCliente = _nombreClienteCtrl.text.trim();
      final venta = Venta(
        id: _uuid.v4(),
        numero: 0, // se reasigna en el datasource (correlativo real)
        fecha: DateTime.now(),
        vendedorId: vendedorId,
        vendedorNombre: usuarioActual?.nombre,
        detalle: detalle,
        total: carritoNotifier.total,
        nombreCliente: nombreCliente.isEmpty ? null : nombreCliente,
      );

      // La venta se manda directo a caja: no se muestra el QR en pantalla
      // (se genera igual internamente como respaldo por si falla la
      // sincronización, pero no bloquea al vendedor con un popup). En el
      // futuro, este paso disparará la impresión del ticket con el QR.
      final ventaCreada = await ref.read(crearVentaUseCaseProvider).call(venta);

      carritoNotifier.limpiar();
      _nombreClienteCtrl.clear();

      if (mounted) {
        final qrPayload = ref.read(qrServiceProvider).generarPayload(ventaCreada);
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Venta #${ventaCreada.numero} enviada'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Mostrale esto a la caja para escanear (o esperá a que llegue solo):'),
                const SizedBox(height: 16),
                QrImageView(data: qrPayload, size: 220),
                const SizedBox(height: 12),
                Text(
                  Formatters.formatearMoneda(ventaCreada.total),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Listo'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la venta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreClienteCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional, para identificar la boleta en caja)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  Formatters.formatearMoneda(widget.total),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
              ),
              onPressed: (widget.total > 0 && !_guardando) ? _finalizarVenta : null,
              child: _guardando
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('FINALIZAR VENTA'),
            ),
          ],
        ),
      ),
    );
  }
}
