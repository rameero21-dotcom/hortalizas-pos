import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/venta.dart';
import '../../../domain/entities/cliente.dart';
import '../widgets/metodo_pago_selector.dart';
import 'caja_home_screen.dart';

/// Detalle de una venta pendiente y flujo de cobro: se puede pagar con
/// un solo método o dividir el total entre varios (ej: parte en
/// efectivo, parte por transferencia). Si alguna parte se cobra a
/// "cuenta corriente", pide elegir el cliente y genera el cargo por esa
/// parte específica.
///
/// La impresión del ticket se dispara del lado del vendedor al finalizar
/// la venta (impresora conectada a esa terminal), no acá en caja.
///
/// Se puede abrir de dos formas:
/// - `ventaId`: la venta viene del stream en tiempo real de Firestore
///   (flujo normal, con conexión).
/// - `ventaDesdeQr`: la venta se reconstruyó leyendo el QR de respaldo
///   (flujo sin conexión); en ese caso no depende del stream.
class VentaDetalleScreen extends ConsumerStatefulWidget {
  final String? ventaId;
  final Venta? ventaDesdeQr;

  const VentaDetalleScreen({super.key, this.ventaId, this.ventaDesdeQr})
      : assert(ventaId != null || ventaDesdeQr != null, 'Se necesita ventaId o ventaDesdeQr');

  @override
  ConsumerState<VentaDetalleScreen> createState() => _VentaDetalleScreenState();
}

class _VentaDetalleScreenState extends ConsumerState<VentaDetalleScreen> {
  final List<DetallePago> _pagos = [];
  Cliente? _clienteSeleccionado;
  bool _cobrando = false;

  double _restante(double total) {
    final cargado = _pagos.fold<double>(0, (acc, p) => acc + p.monto);
    return total - cargado;
  }

  bool get _incluyeCuentaCorriente => _pagos.any((p) => p.metodo == MetodoPago.cuentaCorriente);

  Future<void> _agregarPago(double total) async {
    MetodoPago metodoElegido = MetodoPago.efectivo;
    final montoCtrl = TextEditingController(text: _restante(total).toStringAsFixed(0));

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agregar pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MetodoPagoSelector(
                seleccionado: metodoElegido,
                onChanged: (m) => setDialogState(() => metodoElegido = m),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Agregar')),
          ],
        ),
      ),
    );

    if (confirmado != true) return;
    final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) return;

    setState(() => _pagos.add(DetallePago(metodo: metodoElegido, monto: monto)));

    if (metodoElegido == MetodoPago.cuentaCorriente && _clienteSeleccionado == null) {
      await _elegirCliente();
    }
  }

  Future<void> _elegirCliente() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ref.read(clienteRepositoryProvider).refrescarDesdeRemoto();
    } catch (_) {
      // Sin conexión: seguimos con la caché local que haya.
    }
    if (mounted) Navigator.pop(context); // cierra el indicador de carga

    final clientes = await ref.read(clienteRepositoryProvider).obtenerTodos();
    if (!mounted) return;
    if (clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes cargados. Creá uno primero en Admin > Clientes.')),
      );
      return;
    }
    final elegido = await showModalBottomSheet<Cliente>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: clientes
              .map((c) => ListTile(
                    title: Text(c.nombre),
                    subtitle: Text(Formatters.formatearMoneda(c.saldoCuentaCorriente)),
                    onTap: () => Navigator.pop(context, c),
                  ))
              .toList(),
        ),
      ),
    );
    if (elegido != null) setState(() => _clienteSeleccionado = elegido);
  }

  Future<void> _cobrar(Venta venta) async {
    if (_pagos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregá al menos un método de pago')),
      );
      return;
    }
    if (_restante(venta.total).abs() > 0.5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El total de los pagos no coincide con el total de la venta')),
      );
      return;
    }
    if (_incluyeCuentaCorriente && _clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí a qué cliente cargarle la parte fiada')),
      );
      return;
    }

    setState(() => _cobrando = true);
    try {
      final cajeroId = ref.read(currentUserIdProvider);
      final ventaCobrada = await ref.read(finalizarCobroUseCaseProvider).call(
            venta,
            cajeroId,
            _pagos,
            clienteId: _clienteSeleccionado?.id,
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Venta #${ventaCobrada.numero} cobrada')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cobrar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cobrando = false);
    }
  }

  String _labelMetodo(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.transferencia => 'Transferencia',
        MetodoPago.debito => 'Débito',
        MetodoPago.credito => 'Crédito',
        MetodoPago.cuentaCorriente => 'Cuenta corriente',
      };

  Widget _buildContenido(BuildContext context, Venta venta) {
    final restante = _restante(venta.total);

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              ListTile(
                title: Text('Venta #${venta.numero}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  venta.nombreCliente != null && venta.nombreCliente!.isNotEmpty
                      ? '${venta.nombreCliente}  ·  ${Formatters.formatearFechaHora(venta.fecha)}'
                      : Formatters.formatearFechaHora(venta.fecha),
                ),
              ),
              const Divider(),
              ...venta.detalle.map((item) => ListTile(
                    title: Text(item.nombreProducto),
                    subtitle: Text('Cantidad: ${Formatters.formatearCantidad(item.cantidad)}'),
                    trailing: Text(Formatters.formatearMoneda(item.precioTotal)),
                  )),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pagos', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_pagos.isEmpty)
                      const Text('Todavía no agregaste ningún pago.')
                    else
                      ..._pagos.asMap().entries.map((entry) {
                        final i = entry.key;
                        final p = entry.value;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_labelMetodo(p.metodo)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(Formatters.formatearMoneda(p.monto)),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _pagos.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    Text(
                      restante.abs() < 0.5
                          ? 'Pagos completos'
                          : (restante > 0
                              ? 'Falta cubrir: ${Formatters.formatearMoneda(restante)}'
                              : 'Sobran: ${Formatters.formatearMoneda(-restante)}'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: restante.abs() < 0.5 ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: restante.abs() < 0.5 ? null : () => _agregarPago(venta.total),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar pago'),
                    ),
                    if (_incluyeCuentaCorriente) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _elegirCliente,
                        icon: const Icon(Icons.person),
                        label: Text(_clienteSeleccionado?.nombre ?? 'Elegir cliente para la parte fiada'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(Formatters.formatearMoneda(venta.total),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: _cobrando ? null : () => _cobrar(venta),
            child: _cobrando
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('COBRAR'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Flujo QR: la venta ya la tenemos completa, sin depender del stream.
    if (widget.ventaDesdeQr != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Venta (desde QR)')),
        body: _buildContenido(context, widget.ventaDesdeQr!),
      );
    }

    // Flujo normal: la venta viene del stream en tiempo real de Firestore.
    final ventasAsync = ref.watch(ventasPendientesStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de venta')),
      body: ventasAsync.when(
        data: (ventas) {
          final matches = ventas.where((v) => v.id == widget.ventaId);
          if (matches.isEmpty) {
            return const Center(child: Text('Esta venta ya no está pendiente'));
          }
          return _buildContenido(context, matches.first);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
