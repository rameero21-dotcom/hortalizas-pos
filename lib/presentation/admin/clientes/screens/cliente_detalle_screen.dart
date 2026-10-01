import 'package:flutter/material.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/cliente.dart';
import '../../../../domain/entities/venta.dart';
import '../../../../domain/entities/caja.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/whatsapp_button.dart';

final _movimientosClienteProvider =
    StreamProvider.autoDispose.family<List<MovimientoCuentaCorriente>, String>((ref, clienteId) {
  return ref.watch(clienteRepositoryProvider).observarMovimientosDeCliente(clienteId);
});

/// Cliente puntual, en tiempo real: antes esta pantalla mostraba el
/// saldo con el que se navegó a ella (un snapshot fijo pasado por
/// constructor), así que después de registrar un pago el cartel de
/// "Saldo cuenta corriente" seguía mostrando la deuda vieja hasta
/// volver a entrar a la pantalla — daba la impresión de que el pago no
/// se había guardado, aunque sí había quedado registrado. Se deriva del
/// mismo stream de Firestore que ya usa el listado de clientes.
///
/// Público (sin guion bajo) porque ClienteFormScreen también lo usa,
/// para calcular el ajuste manual de saldo contra el valor más
/// reciente en vez de la foto fija con la que se abrió el formulario.
final clienteActualProvider = StreamProvider.autoDispose.family<Cliente?, String>((ref, clienteId) {
  return ref.watch(clienteRepositoryProvider).observarTodos().map((clientes) {
    for (final c in clientes) {
      if (c.id == clienteId) return c;
    }
    return null;
  });
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

  /// Registra un pago del cliente contra su deuda de cuenta corriente.
  /// Los cargos (fiado) ya NO se generan a mano acá: siempre nacen de
  /// una venta real cobrada como "cuenta corriente" (así queda la
  /// boleta a su nombre, visible en la pestaña "Boletas"). Esta
  /// pantalla es solo para gente que YA debe algo y viene a pagarlo.
  Future<void> _registrarPago() async {
    final montoCtrl = TextEditingController();
    final detalleCtrl = TextEditingController();
    // Si paga en efectivo, esa plata entra de verdad a la caja y tiene
    // que reflejarse ahí.
    MetodoPago metodoPago = MetodoPago.efectivo;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar pago'),
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('¿Cómo paga?', style: TextStyle(color: Colors.grey.shade400)),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [MetodoPago.efectivo, MetodoPago.transferencia].map((m) {
                  return ChoiceChip(
                    label: Text(m == MetodoPago.efectivo ? 'Efectivo' : 'Transferencia'),
                    selected: metodoPago == m,
                    onSelected: (_) => setDialogState(() => metodoPago = m),
                  );
                }).toList(),
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
    final monto = Formatters.parsearMonto(montoCtrl.text);
    if (monto == null || monto <= 0) return;
    final detalle = detalleCtrl.text.trim().isEmpty ? '(sin detalle)' : detalleCtrl.text.trim();

    final usuarioId = ref.read(currentUserIdProvider);
    try {
      await ref.read(clienteRepositoryProvider).registrarMovimientoCuenta(
            clienteId: widget.cliente.id,
            tipo: TipoMovimientoCuenta.pago,
            monto: monto,
            detalle: detalle,
            usuarioId: usuarioId,
            metodoPago: metodoPago,
          );

      // Si el cliente pagó en EFECTIVO, esa plata entró de verdad a la
      // caja: se registra como ingreso manual para que el arqueo de caja
      // lo tenga en cuenta al calcular el efectivo esperado. Si fue por
      // transferencia, no toca la caja física (no hay billetes de por
      // medio), pero el pago ya quedó reflejado en la cuenta corriente.
      if (metodoPago == MetodoPago.efectivo) {
        await ref.read(cajaRepositoryProvider).registrarMovimiento(
              tipo: TipoMovimientoCaja.ingreso,
              monto: monto,
              detalle: 'Pago cuenta corriente - ${widget.cliente.nombre}: $detalle',
              usuarioId: usuarioId,
            );
      }

      ref.invalidate(_movimientosClienteProvider(widget.cliente.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pago de ${Formatters.formatearMoneda(monto)} registrado')),
        );
      }
    } catch (e) {
      // Antes, si esto fallaba (ej. el cliente no estaba en la copia
      // local del dispositivo), la pantalla no mostraba nada — parecía
      // que el pago simplemente no se guardaba. Ahora se avisa.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo registrar el pago: $e')),
        );
      }
    }
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
    // Se parte del cliente con el que se navegó acá (para no mostrar la
    // pantalla vacía mientras carga) y se reemplaza en cuanto llega el
    // primer valor del stream en tiempo real, así el saldo reacciona a
    // los pagos/cargos que se registren sin salir de la pantalla.
    final cliente = ref.watch(clienteActualProvider(widget.cliente.id)).valueOrNull ?? widget.cliente;
    final movimientosAsync = ref.watch(_movimientosClienteProvider(cliente.id));
    final boletasAsync = ref.watch(_boletasClienteProvider(cliente.id));

    return Scaffold(
      appBar: GradientAppBar(
        title: Text(cliente.nombre),
        actions: [WhatsappButton(telefono: cliente.telefono)],
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
            color: (cliente.saldoCuentaCorriente < 0 ? Colors.red : Colors.green).withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cliente.saldoCuentaCorriente < 0 ? Colors.red : Colors.green),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Saldo cuenta corriente', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.formatearMoneda(cliente.saldoCuentaCorriente),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: cliente.saldoCuentaCorriente < 0 ? Colors.red.shade300 : Colors.green.shade300,
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
            child: OutlinedButton.icon(
              onPressed: _registrarPago,
              icon: const Icon(Icons.check),
              label: const Text('Registrar pago'),
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
                                    subtitle: Text('Cantidad: ${Formatters.formatearCantidad(d.cantidad)}'),
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
                  loading: () => const LoadingWidget(),
                  error: (e, __) => Center(child: Text('Error: $e')),
                ),
                // ===== Pagos y cargos manuales (aparte de boletas) =====
                movimientosAsync.when(
                  data: (movimientos) {
                    if (movimientos.isEmpty) {
                      return const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'Sin movimientos manuales todavía.',
                      );
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
                              color: esCargo ? Colors.red.shade300 : Colors.green.shade300,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingWidget(),
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
