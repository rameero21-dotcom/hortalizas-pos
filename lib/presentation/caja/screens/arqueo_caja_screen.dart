import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/caja.dart';
import '../../../domain/entities/venta.dart';
import 'historial_cierres_screen.dart';

/// Denominaciones de billetes en pesos argentinos, tal como se cuentan
/// en la planilla (de mayor a menor).
const _denominaciones = [20000, 10000, 2000, 1000, 500, 100, 50, 20, 10];

/// Un ítem de venta para mostrar dentro del desplegable de efectivo o
/// de cuenta corriente (puede ser solo una PARTE de la venta, si el
/// pago fue dividido entre varios métodos).
class _ItemVentaCaja {
  final int numero;
  final String? nombreCliente;
  final double monto;
  final String metodoLabel;

  _ItemVentaCaja({
    required this.numero,
    required this.nombreCliente,
    required this.monto,
    required this.metodoLabel,
  });
}

String _labelMetodo(MetodoPago m) => switch (m) {
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.transferencia => 'Transferencia',
      MetodoPago.debito => 'Débito',
      MetodoPago.credito => 'Crédito',
      MetodoPago.cuentaCorriente => 'Fiado',
    };

/// Todas las ventas cobradas HOY (se procesan acá mismo para armar
/// tanto los totales como el detalle de cada venta en los desplegables).
final _ventasHoyProvider = FutureProvider.autoDispose<List<Venta>>((ref) async {
  final ahora = DateTime.now();
  final inicio = DateTime(ahora.year, ahora.month, ahora.day);
  final fin = inicio.add(const Duration(days: 1));
  final ventas = await ref.watch(ventaRepositoryProvider).obtenerPorRangoFechaGlobal(inicio, fin);
  return ventas.where((v) => v.estado == EstadoVenta.cobrada).toList();
});

/// Movimientos manuales de caja de hoy (ingresos/egresos aparte de ventas).
final _movimientosCajaHoyProvider = FutureProvider.autoDispose<List<MovimientoCaja>>((ref) async {
  final ahora = DateTime.now();
  final inicio = DateTime(ahora.year, ahora.month, ahora.day);
  final fin = inicio.add(const Duration(days: 1));
  return ref.watch(cajaRepositoryProvider).obtenerMovimientos(inicio, fin);
});

/// Pantalla de arqueo/cierre de caja: muestra lo que el sistema calcula
/// que debería haber en efectivo (ventas en efectivo + ingresos manuales
/// - egresos manuales), y permite contar los billetes reales para
/// comparar y cerrar la caja del día — igual que el bloque de caja de
/// la planilla (EFECTIVO, CAJA INICIO, BILLETE/CANTIDAD, etc.).
///
/// "Cuenta corriente" acá agrupa tanto lo fiado como lo cobrado por
/// transferencia: en ninguno de los dos casos entra plata física a la
/// caja, así que para el arqueo del día se tratan igual.
class ArqueoCajaScreen extends ConsumerStatefulWidget {
  const ArqueoCajaScreen({super.key});

  @override
  ConsumerState<ArqueoCajaScreen> createState() => _ArqueoCajaScreenState();
}

class _ArqueoCajaScreenState extends ConsumerState<ArqueoCajaScreen> {
  final _cajaInicioCtrl = TextEditingController(text: '0');
  final Map<int, TextEditingController> _billeteCtrls = {
    for (final d in _denominaciones) d: TextEditingController(text: '0'),
  };
  bool _guardando = false;

  @override
  void dispose() {
    _cajaInicioCtrl.dispose();
    for (final c in _billeteCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalContado {
    double total = 0;
    for (final d in _denominaciones) {
      final cantidad = int.tryParse(_billeteCtrls[d]!.text) ?? 0;
      total += d * cantidad;
    }
    return total;
  }

  Future<void> _cerrarCaja() async {
    setState(() => _guardando = true);
    try {
      final usuarioId = ref.read(currentUserIdProvider);
      final billetes = _denominaciones
          .map((d) => ConteoBillete(denominacion: d, cantidad: int.tryParse(_billeteCtrls[d]!.text) ?? 0))
          .where((b) => b.cantidad > 0)
          .toList();
      await ref.read(cajaRepositoryProvider).guardarCierre(
            cajaInicio: double.tryParse(_cajaInicioCtrl.text.replaceAll(',', '.')) ?? 0,
            billetes: billetes,
            usuarioId: usuarioId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Caja cerrada y guardada (${Formatters.formatearMoneda(_totalContado)})')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregarMovimientoManual(TipoMovimientoCaja tipo) async {
    final montoCtrl = TextEditingController();
    final detalleCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tipo == TipoMovimientoCaja.ingreso ? 'Ingreso manual' : 'Egreso manual'),
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
              decoration: const InputDecoration(labelText: 'Detalle / cliente', border: OutlineInputBorder()),
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
    await ref.read(cajaRepositoryProvider).registrarMovimiento(
          tipo: tipo,
          monto: monto,
          detalle: detalleCtrl.text.trim().isEmpty ? '(sin detalle)' : detalleCtrl.text.trim(),
          usuarioId: usuarioId,
        );
    ref.invalidate(_movimientosCajaHoyProvider);
  }

  /// Separa cada venta cobrada hoy en ítems por método de pago (una
  /// venta con pago dividido aparece una vez por cada parte), y
  /// devuelve los dos grupos que nos interesan: efectivo, y
  /// cuenta corriente (fiado + transferencia juntos).
  ({List<_ItemVentaCaja> efectivo, List<_ItemVentaCaja> cuentaCorriente}) _agruparVentas(
      List<Venta> ventas) {
    final efectivo = <_ItemVentaCaja>[];
    final cuentaCorriente = <_ItemVentaCaja>[];

    for (final v in ventas) {
      final pagos = v.pagos.isNotEmpty
          ? v.pagos
          : (v.metodoPago != null ? [DetallePago(metodo: v.metodoPago!, monto: v.total)] : <DetallePago>[]);

      for (final p in pagos) {
        final item = _ItemVentaCaja(
          numero: v.numero,
          nombreCliente: v.nombreCliente,
          monto: p.monto,
          metodoLabel: _labelMetodo(p.metodo),
        );
        if (p.metodo == MetodoPago.efectivo) {
          efectivo.add(item);
        } else if (p.metodo == MetodoPago.cuentaCorriente || p.metodo == MetodoPago.transferencia) {
          cuentaCorriente.add(item);
        }
      }
    }
    return (efectivo: efectivo, cuentaCorriente: cuentaCorriente);
  }

  @override
  Widget build(BuildContext context) {
    final ventasAsync = ref.watch(_ventasHoyProvider);
    final movimientosAsync = ref.watch(_movimientosCajaHoyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arqueo de caja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver cierres guardados',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistorialCierresScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _cajaInicioCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Caja inicio (efectivo con el que arrancó el día)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ventasAsync.when(
            data: (ventas) => movimientosAsync.when(
              data: (movimientos) {
                final grupos = _agruparVentas(ventas);
                final totalEfectivo = grupos.efectivo.fold(0.0, (acc, i) => acc + i.monto);
                final totalCuentaCorriente = grupos.cuentaCorriente.fold(0.0, (acc, i) => acc + i.monto);
                final ingresos = movimientos
                    .where((m) => m.tipo == TipoMovimientoCaja.ingreso)
                    .fold(0.0, (acc, m) => acc + m.monto);
                final egresos = movimientos
                    .where((m) => m.tipo == TipoMovimientoCaja.egreso)
                    .fold(0.0, (acc, m) => acc + m.monto);
                final cajaInicio = double.tryParse(_cajaInicioCtrl.text.replaceAll(',', '.')) ?? 0;
                // La cuenta corriente (fiado + transferencia) NO suma al
                // efectivo esperado: esa plata no entró físicamente a la
                // caja como billetes, se muestra solo a modo informativo.
                final totalEsperado = cajaInicio + totalEfectivo + ingresos - egresos;
                final diferencia = _totalContado - totalEsperado;

                return Column(
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _filaResumen('Ventas en efectivo hoy', totalEfectivo),
                            _filaResumen('Ventas en cuenta corriente hoy (fiado + transferencia)',
                                totalCuentaCorriente),
                            _filaResumen('Ingresos manuales', ingresos),
                            _filaResumen('Egresos manuales', -egresos),
                            const Divider(),
                            _filaResumen('Total esperado en caja', totalEsperado, negrita: true),
                            _filaResumen('Total contado (billetes)', _totalContado, negrita: true),
                            const Divider(),
                            _filaResumen('Diferencia', diferencia,
                                negrita: true, colorSegunSigno: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _desplegableVentas('Ventas en efectivo', grupos.efectivo, Colors.green.shade700),
                    const SizedBox(height: 8),
                    _desplegableVentas(
                        'Ventas en cuenta corriente (fiado + transferencia)',
                        grupos.cuentaCorriente,
                        Colors.blue.shade700),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Text('Error: $e'),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _agregarMovimientoManual(TipoMovimientoCaja.ingreso),
                  icon: const Icon(Icons.add),
                  label: const Text('Ingreso manual'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _agregarMovimientoManual(TipoMovimientoCaja.egreso),
                  icon: const Icon(Icons.remove),
                  label: const Text('Egreso manual'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Conteo de billetes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ..._denominaciones.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 90, child: Text(Formatters.formatearMoneda(d))),
                    Expanded(
                      child: TextField(
                        controller: _billeteCtrls[d],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad de billetes',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        Formatters.formatearMoneda(d * (int.tryParse(_billeteCtrls[d]!.text) ?? 0)),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _guardando ? null : _cerrarCaja,
            child: _guardando
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('CERRAR CAJA'),
          ),
        ],
      ),
    );
  }

  Widget _filaResumen(String titulo, double valor, {bool negrita = false, bool colorSegunSigno = false}) {
    final color = colorSegunSigno ? (valor >= 0 ? Colors.green.shade700 : Colors.red.shade700) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(titulo, style: TextStyle(fontWeight: negrita ? FontWeight.bold : FontWeight.normal))),
          Text(
            Formatters.formatearMoneda(valor),
            style: TextStyle(fontWeight: negrita ? FontWeight.bold : FontWeight.normal, color: color),
          ),
        ],
      ),
    );
  }

  Widget _desplegableVentas(String titulo, List<_ItemVentaCaja> items, Color color) {
    final total = items.fold(0.0, (acc, i) => acc + i.monto);
    return Card(
      child: ExpansionTile(
        title: Text(titulo),
        subtitle: Text('${items.length} venta(s) · ${Formatters.formatearMoneda(total)}'),
        children: items.isEmpty
            ? [const Padding(padding: EdgeInsets.all(16), child: Text('Sin ventas todavía hoy.'))]
            : items
                .map((i) => ListTile(
                      dense: true,
                      title: Text(
                        i.nombreCliente != null && i.nombreCliente!.isNotEmpty
                            ? 'Venta #${i.numero} · ${i.nombreCliente}'
                            : 'Venta #${i.numero}',
                      ),
                      subtitle: Text(i.metodoLabel),
                      trailing: Text(
                        Formatters.formatearMoneda(i.monto),
                        style: TextStyle(fontWeight: FontWeight.bold, color: color),
                      ),
                    ))
                .toList(),
      ),
    );
  }
}
