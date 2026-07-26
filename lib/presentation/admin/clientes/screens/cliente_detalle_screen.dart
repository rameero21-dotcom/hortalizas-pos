import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/cliente.dart';

final _movimientosClienteProvider =
    FutureProvider.autoDispose.family<List<MovimientoCuentaCorriente>, String>((ref, clienteId) {
  return ref.watch(clienteRepositoryProvider).obtenerMovimientosCuenta(clienteId);
});

/// Cuenta corriente de un cliente: saldo actual e historial de cargos
/// (fiado) y pagos (efectivo o transferencia), igual que la columna
/// "CLIENTE / CTA CTE" de la planilla.
class ClienteDetalleScreen extends ConsumerWidget {
  final Cliente cliente;
  const ClienteDetalleScreen({super.key, required this.cliente});

  Future<void> _registrarMovimiento(
      BuildContext context, WidgetRef ref, TipoMovimientoCuenta tipo) async {
    final montoCtrl = TextEditingController();
    final detalleCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tipo == TipoMovimientoCuenta.cargo
            ? 'Nuevo cargo (fiado)'
            : 'Registrar pago/transferencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detalleCtrl,
              decoration: const InputDecoration(labelText: 'Detalle', border: OutlineInputBorder()),
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
    final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) return;

    final usuarioId = ref.read(currentUserIdProvider);
    await ref.read(clienteRepositoryProvider).registrarMovimientoCuenta(
          clienteId: cliente.id,
          tipo: tipo,
          monto: monto,
          detalle: detalleCtrl.text.trim().isEmpty ? '(sin detalle)' : detalleCtrl.text.trim(),
          usuarioId: usuarioId,
        );
    ref.invalidate(_movimientosClienteProvider(cliente.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientosAsync = ref.watch(_movimientosClienteProvider(cliente.id));

    return Scaffold(
      appBar: AppBar(title: Text(cliente.nombre)),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            color: cliente.saldoCuentaCorriente < 0
                ? Colors.red.shade50
                : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Saldo cuenta corriente', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.formatearMoneda(cliente.saldoCuentaCorriente),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: cliente.saldoCuentaCorriente < 0
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                  Text(
                    cliente.saldoCuentaCorriente < 0 ? 'El cliente debe' : 'Sin deuda',
                    style: const TextStyle(fontSize: 12),
                  ),
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
                    onPressed: () => _registrarMovimiento(context, ref, TipoMovimientoCuenta.cargo),
                    icon: const Icon(Icons.add),
                    label: const Text('Cargo (fiado)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _registrarMovimiento(context, ref, TipoMovimientoCuenta.pago),
                    icon: const Icon(Icons.check),
                    label: const Text('Registrar pago'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: movimientosAsync.when(
              data: (movimientos) {
                if (movimientos.isEmpty) {
                  return const Center(child: Text('Sin movimientos todavía.'));
                }
                return ListView.builder(
                  itemCount: movimientos.length,
                  itemBuilder: (context, index) {
                    final m = movimientos[index];
                    final esCargo = m.tipo == TipoMovimientoCuenta.cargo;
                    return ListTile(
                      leading: Icon(
                        esCargo ? Icons.arrow_upward : Icons.arrow_downward,
                        color: esCargo ? Colors.red : Colors.green,
                      ),
                      title: Text(m.detalle),
                      subtitle: Text(Formatters.formatearFechaHora(m.fecha)),
                      trailing: Text(
                        Formatters.formatearMoneda(m.monto),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: esCargo ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
