import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/venta.dart';
import '../../shared/widgets/qr_ticket_dialog.dart';
import '../providers/carrito_provider.dart';
import '../widgets/producto_search_field.dart';
import '../widgets/item_carrito_tile.dart';

final _uuid = Uuid();

/// Pantalla principal del vendedor: buscar producto, ingresar cantidad
/// y precio TOTAL, agregar al carrito, y finalizar la venta.
///
/// Layout según especificación:
/// - Buscador de productos (lista desplegable)
/// - Cantidad
/// - Precio total
/// - Botón Agregar
/// - Lista de productos agregados (editar / eliminar)
/// - TOTAL
/// - Botón enorme "FINALIZAR VENTA"
class NuevaVentaScreen extends ConsumerWidget {
  const NuevaVentaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    final total = ref.watch(carritoProvider.notifier).total;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva venta')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: ProductoSearchField(),
          ),
          Expanded(
            child: carrito.isEmpty
                ? const Center(child: Text('Agregá productos a la venta'))
                : ListView.builder(
                    itemCount: carrito.length,
                    itemBuilder: (context, index) => ItemCarritoTile(
                      item: carrito[index],
                      onEliminar: () =>
                          ref.read(carritoProvider.notifier).eliminarProducto(index),
                      onEditar: () {
                        // TODO: abrir diálogo de edición (cantidad/precio) reutilizando ProductoSearchField.
                      },
                    ),
                  ),
          ),
          _ResumenTotalYFinalizar(total: total),
        ],
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
  bool _guardando = false;

  Future<void> _finalizarVenta() async {
    final carritoNotifier = ref.read(carritoProvider.notifier);
    final detalle = ref.read(carritoProvider);
    if (detalle.isEmpty) return;

    setState(() => _guardando = true);
    try {
      final vendedorId = ref.read(currentUserIdProvider);
      final venta = Venta(
        id: _uuid.v4(),
        numero: 0, // se reasigna en el datasource (correlativo real)
        fecha: DateTime.now(),
        vendedorId: vendedorId,
        detalle: detalle,
        total: carritoNotifier.total,
      );

      final ventaCreada = await ref.read(crearVentaUseCaseProvider).call(venta);

      if (!mounted) return;

      final qrPayload = ref.read(qrServiceProvider).generarPayload(ventaCreada);

      await showDialog(
        context: context,
        builder: (_) => QrTicketDialog(payload: qrPayload, numeroVenta: ventaCreada.numero),
      );

      carritoNotifier.limpiar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Venta #${ventaCreada.numero} enviada a caja')),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(Formatters.formatearMoneda(widget.total),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (widget.total > 0 && !_guardando) ? _finalizarVenta : null,
              child: _guardando
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('FINALIZAR VENTA'),
            ),
          ],
        ),
      ),
    );
  }
}
