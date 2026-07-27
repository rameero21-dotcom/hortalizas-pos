import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/cliente.dart';
import '../../../../domain/entities/venta.dart';

final _movimientosClienteProvider =
    FutureProvider.autoDispose.family<List<MovimientoCuentaCorriente>, String>((ref, clienteId) {
  return ref.watch(clienteRepositoryProvider).obtenerMovimientosCuenta(clienteId);
});

final _boletasClienteProvider =
    FutureProvider.autoDispose.family<List<Venta>, String>((ref, clienteId) {
  return ref.watch(ventaRepositoryProvider).obtenerPorCliente(clienteId);
});

/// Cuenta corriente de un cliente: saldo actual, boletas (ventas) a su
/// nombre con el detalle de productos y forma de pago, e historial de
/// pagos/cargos manuales — igual que la columna "CLIENTE / CTA CTE" de
/// la planilla, pero con el detalle completo de cada venta.
class ClienteDetalleScreen extends ConsumerStatefulWidget {
  final Cliente cliente;
  const ClienteDetalleScreen({super.key, required this.cliente});

  @override
  ConsumerState<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends ConsumerState<ClienteDetalleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _registrarMovimiento(TipoMovimientoCuenta tipo) async {
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
          clienteId: widget.cliente.id,
          tipo: tipo,
          monto: monto,
          detalle: detalleCtrl.text.trim().isEmpty ? '(sin detalle)' : detalleCtrl.text.trim(),
          usuarioId: usuarioId,
        );
    ref.invalidate(_movimientosClienteProvider(widget.cliente.id));
  }

  String _labelMetodo(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.transferencia => 'Transferencia',
        MetodoPago.debito => 'Débito',
        MetodoPago.credito => 'Crédito',
        MetodoPago.cuentaCorriente => 'Cuenta corriente',
      };

  @override
  Widget build(BuildContext context) {
    final cliente = widget.cliente;
    final movimientosAsync = ref.watch(_movimientosClienteProvider(cliente.id));
    final boletasAsync = ref.watch(_boletasClienteProvider(cliente.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(cliente.nombre),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Boletas'),
            Tab(text: 'Pagos y cargos'),
          ],
        ),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            color: cliente.saldoCuentaCorriente < 0 ? Colors.red.shade50 : Colors.green.shade50,
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
                      color: cliente.saldoCuentaCorriente < 0 ? Colors.red.shade700 : Colors.green.shade700,
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
                    onPressed: () => _registrarMovimiento(TipoMovimientoCuenta.cargo),
                    icon: const Icon(Icons.add),
                    label: const Text('Cargo (fiado)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _registrarMovimiento(TipoMovimientoCuenta.pago),
                    icon: const Icon(Icons.check),
                    label: const Text('Registrar pago'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ===== Boletas: ventas reales cargadas a este cliente =====
                boletasAsync.when(
                  data: (boletas) {
                    if (boletas.isEmpty) {
                      return const Center(child: Text('Todavía no tiene boletas a su nombre.'));
                    }
                    return ListView.builder(
                      itemCount: boletas.length,
                      itemBuilder: (context, index) {
                        final venta = boletas[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ExpansionTile(
                            title: Text('Venta #${venta.numero}'),
                            subtitle: Text(Formatters.formatearFechaHora(venta.fecha)),
                            trailing: Text(
                              Formatters.formatearMoneda(venta.total),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            children: [
                              ...venta.detalle.map((d) => ListTile(
                                    dense: true,
                                    title: Text(d.nombreProducto),
                                    subtitle: Text('Cantidad: ${d.cantidad}'),
                                    trailing: Text(Formatters.formatearMoneda(d.precioTotal)),
                                  )),
                              if (venta.pagos.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(),
                                      const Text('Cómo se pagó', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ...venta.pagos.map((p) => Text(
                                          '${_labelMetodo(p.metodo)}: ${Formatters.formatearMoneda(p.monto)}')),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, __) => Center(child: Text('Error: $e')),
                ),
                // ===== Pagos y cargos manuales (aparte de boletas) =====
                movimientosAsync.when(
                  data: (movimientos) {
                    if (movimientos.isEmpty) {
                      return const Center(child: Text('Sin movimientos manuales todavía.'));
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
