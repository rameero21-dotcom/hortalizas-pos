import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import 'proveedor_form_screen.dart';
import 'proveedor_detalle_screen.dart';
import '../../../shared/utils/borrado_con_deshacer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/whatsapp_button.dart';

/// Escucha en tiempo real: un proveedor creado/editado desde CUALQUIER
/// dispositivo aparece acá sin necesitar refrescar manualmente.
final proveedoresListProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(proveedorRepositoryProvider).observarTodos().map((proveedores) {
    final ordenados = List.of(proveedores);
    ordenados.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return ordenados;
  });
});

/// Listado de proveedores: de quién se compra mercadería. Cada uno
/// tiene su propio historial de pedidos (producto, cantidad, forma de
/// pago) accesible tocando la tarjeta.
class ProveedoresScreen extends ConsumerStatefulWidget {
  const ProveedoresScreen({super.key});

  @override
  ConsumerState<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends ConsumerState<ProveedoresScreen>
    with BorradoConDeshacerMixin<ProveedoresScreen> {
  @override
  Widget build(BuildContext context) {
    final proveedoresAsync = ref.watch(proveedoresListProvider);

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Proveedores')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProveedorFormScreen()),
          );
          ref.invalidate(proveedoresListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: proveedoresAsync.when(
        data: (todos) {
          final proveedores = todos.where((p) => !idsOcultos.contains(p.id)).toList();
          if (proveedores.isEmpty) {
            return const EmptyState(
              icon: Icons.local_shipping_outlined,
              message: 'No hay proveedores cargados. Tocá + para agregar uno.',
            );
          }
          final totalQueLesDebemos = proveedores
              .where((p) => p.saldoCuentaCorriente > 0)
              .fold(0.0, (acc, p) => acc + p.saldoCuentaCorriente);
          return Column(
            children: [
              if (totalQueLesDebemos > 0)
                Card(
                  margin: const EdgeInsets.all(12),
                  color: Colors.red.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total que les debemos a los proveedores'),
                        Text(
                          Formatters.formatearMoneda(totalQueLesDebemos),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade300),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: proveedores.length,
                  itemBuilder: (context, index) {
                    final p = proveedores[index];
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
                                title: const Text('Eliminar proveedor'),
                                content: Text(
                                  p.saldoCuentaCorriente != 0
                                      ? '¿Eliminar a ${p.nombre}? Todavía hay un saldo de '
                                          '${Formatters.formatearMoneda(p.saldoCuentaCorriente)} en su cuenta.'
                                      : '¿Eliminar a ${p.nombre}?',
                                ),
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
                      onDismissed: (_) => eliminarConDeshacer(
                        id: p.id,
                        mensaje: 'Se eliminó a ${p.nombre}',
                        eliminar: () => ref.read(proveedorRepositoryProvider).eliminar(p.id),
                        alConfirmar: () => ref.invalidate(proveedoresListProvider),
                      ),
                      child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.local_shipping_rounded,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(p.nombre),
                        subtitle: Text(p.telefono.isEmpty ? 'Sin teléfono cargado' : p.telefono),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p.saldoCuentaCorriente != 0) ...[
                              Text(
                                Formatters.formatearMoneda(p.saldoCuentaCorriente.abs()),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: p.saldoCuentaCorriente > 0 ? Colors.red : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            WhatsappButton(
                              telefono: p.telefono,
                              size: 18,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProveedorFormScreen(proveedor: p)),
                                );
                                ref.invalidate(proveedoresListProvider);
                              },
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProveedorDetalleScreen(proveedor: p)),
                        ),
                      ),
                      ),
                    )
                        .animate(delay: (index.clamp(0, 12) * 40).ms)
                        .fadeIn(duration: 220.ms)
                        .slideX(begin: 0.04, end: 0, duration: 220.ms, curve: Curves.easeOut);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, __) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
