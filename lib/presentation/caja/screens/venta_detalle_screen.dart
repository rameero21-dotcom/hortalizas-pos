import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/venta.dart';
import '../../../domain/entities/cliente.dart';
import '../widgets/metodo_pago_selector.dart';
import 'caja_home_screen.dart';

/// Detalle de una venta pendiente y flujo de cobro completo:
/// método de pago -> descuento automático de stock -> impresión de
/// ticket térmico. Si se paga a "cuenta corriente", pide elegir el
/// cliente y genera el cargo (fiado) automáticamente.
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
  MetodoPago? _metodoSeleccionado;
  Cliente? _clienteSeleccionado;
  bool _cobrando = false;

  Future<void> _elegirCliente() async {
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
    if (_metodoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí un método de pago')),
      );
      return;
    }
    if (_metodoSeleccionado == MetodoPago.cuentaCorriente && _clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí a qué cliente cargarle la venta')),
      );
      return;
    }

    setState(() => _cobrando = true);
    try {
      final cajeroId = ref.read(currentUserIdProvider);
      final ventaCobrada = await ref.read(finalizarCobroUseCaseProvider).call(
            venta,
            cajeroId,
            _metodoSeleccionado!,
            clienteId: _clienteSeleccionado?.id,
          );

      // La impresión no bloquea el cobro: si falla, la venta ya quedó
      // cobrada y con stock descontado; el cajero puede reimprimir después
      // (Fase 4 - historial).
      String? errorImpresion;
      try {
        await ref.read(printServiceProvider).imprimirTicket(
              venta: ventaCobrada,
              nombreComercio: AppConstants.nombreComercio,
            );
      } on PrinterException catch (e) {
        errorImpresion = e.mensaje;
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorImpresion == null
              ? 'Venta #${ventaCobrada.numero} cobrada'
              : 'Venta #${ventaCobrada.numero} cobrada. No se pudo imprimir: $errorImpresion'),
        ),
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

  Widget _buildContenido(BuildContext context, Venta venta) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              ListTile(
                title: Text('Venta #${venta.numero}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(Formatters.formatearFechaHora(venta.fecha)),
              ),
              const Divider(),
              ...venta.detalle.map((item) => ListTile(
                    title: Text(item.nombreProducto),
                    subtitle: Text('Cantidad: ${item.cantidad}'),
                    trailing: Text(Formatters.formatearMoneda(item.precioTotal)),
                  )),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Método de pago', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    MetodoPagoSelector(
                      seleccionado: _metodoSeleccionado,
                      onChanged: (m) => setState(() => _metodoSeleccionado = m),
                    ),
                    if (_metodoSeleccionado == MetodoPago.cuentaCorriente) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _elegirCliente,
                        icon: const Icon(Icons.person),
                        label: Text(_clienteSeleccionado?.nombre ?? 'Elegir cliente'),
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
                : const Text('COBRAR E IMPRIMIR'),
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
