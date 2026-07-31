import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/venta.dart';
import '../../../../domain/entities/cliente.dart';

class _FiltrosFacturacion {
  final DateTime desde;
  final DateTime hasta;
  _FiltrosFacturacion({required this.desde, required this.hasta});
}

/// Monto neto = bruto / 1.105, siempre redondeado PARA ARRIBA (nunca
/// para abajo), tal como lo pidió el contador.
int _montoNeto(double bruto) => (bruto / 1.105).ceil();

final _filtrosFacturacionProvider = StateProvider<_FiltrosFacturacion>((ref) {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  return _FiltrosFacturacion(desde: hoy, hasta: hoy.add(const Duration(days: 1)));
});

/// Una entrada para el contador: puede venir de una venta cobrada por
/// transferencia, o de un pago de cuenta corriente hecho por
/// transferencia — cualquiera de los dos hay que facturarlo igual.
class _ItemFacturacion {
  final String id;
  final String titulo;
  final String subtitulo;
  final bool faltaCuitDni;
  final DateTime fecha;
  final double montoBruto;
  _ItemFacturacion({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.faltaCuitDni,
    required this.fecha,
    required this.montoBruto,
  });
}

final _facturacionProvider = FutureProvider.autoDispose<List<_ItemFacturacion>>((ref) async {
  final filtros = ref.watch(_filtrosFacturacionProvider);
  final items = <_ItemFacturacion>[];

  // ---- Paso 1: Ventas cobradas (total o parcialmente) por transferencia ----
  final ventaRepo = ref.watch(ventaRepositoryProvider);
  final todasLasVentas = await ventaRepo.obtenerPorRangoFechaGlobal(filtros.desde, filtros.hasta);
  final cobradas = todasLasVentas.where((v) => v.estado == EstadoVenta.cobrada);
  for (final v in cobradas) {
    double montoTransferido = 0;
    if (v.pagos.isNotEmpty) {
      montoTransferido = v.pagos
          .where((p) => p.metodo == MetodoPago.transferencia)
          .fold(0.0, (acc, p) => acc + p.monto);
    } else if (v.metodoPago == MetodoPago.transferencia) {
      montoTransferido = v.total;
    }
    if (montoTransferido > 0) {
      final tieneCuitDni = v.cuitDniComprador != null && v.cuitDniComprador!.isNotEmpty;
      items.add(_ItemFacturacion(
        id: v.id,
        titulo: v.nombreCliente != null && v.nombreCliente!.isNotEmpty
            ? 'Venta #${v.numero} · ${v.nombreCliente}'
            : 'Venta #${v.numero}',
        subtitulo: tieneCuitDni ? 'CUIT/DNI: ${v.cuitDniComprador}' : 'Sin CUIT/DNI cargado',
        faltaCuitDni: !tieneCuitDni,
        fecha: v.fecha,
        montoBruto: montoTransferido,
      ));
    }
  }

  // ---- Paso 2: Pagos de cuenta corriente hechos por transferencia ----
  final clienteRepo = ref.watch(clienteRepositoryProvider);
  final clientes = await clienteRepo.obtenerTodos();
  final nombrePorCliente = {for (final c in clientes) c.id: c.nombre};
  final cuitDniPorCliente = {for (final c in clientes) c.id: c.cuitODni};
  final movimientos = await clienteRepo.obtenerMovimientosCuentaGlobal(filtros.desde, filtros.hasta);
  for (final m in movimientos) {
    if (m.tipo != TipoMovimientoCuenta.pago || m.metodoPago != MetodoPago.transferencia) continue;
    final nombreCliente = nombrePorCliente[m.clienteId] ?? '(cliente eliminado)';
    final cuitDni = cuitDniPorCliente[m.clienteId] ?? '';
    final tieneCuitDni = cuitDni.isNotEmpty;
    items.add(_ItemFacturacion(
      id: m.id,
      titulo: 'Pago de cuenta corriente · $nombreCliente',
      subtitulo: tieneCuitDni ? 'CUIT/DNI: $cuitDni' : 'Sin CUIT/DNI cargado',
      faltaCuitDni: !tieneCuitDni,
      fecha: m.fecha,
      montoBruto: m.monto,
    ));
  }

  // Sacar los que ya se marcaron como facturados (deslizando).
  final idsMarcados = await ref.watch(facturacionMarcadoRepositoryProvider).obtenerIdsMarcadosGlobal();
  items.removeWhere((i) => idsMarcados.contains(i.id));

  items.sort((a, b) => b.fecha.compareTo(a.fecha));
  return items;
});

/// Pantalla pensada para el contador: solo lo que se cobró por
/// transferencia, con el CUIT/DNI de cada comprador, para saber qué
/// facturar. Funciona igual que Historial: se puede ver por día,
/// semana, mes, o elegir cualquier rango de fechas.
class FacturacionScreen extends ConsumerWidget {
  const FacturacionScreen({super.key});

  Future<void> _elegirRangoPersonalizado(BuildContext context, WidgetRef ref) async {
    final filtros = ref.read(_filtrosFacturacionProvider);
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: filtros.desde, end: filtros.hasta),
    );
    if (rango != null) {
      ref.read(_filtrosFacturacionProvider.notifier).state = _FiltrosFacturacion(
        desde: rango.start,
        hasta: rango.end.add(const Duration(days: 1)),
      );
    }
  }

  void _elegirDia(WidgetRef ref) {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    ref.read(_filtrosFacturacionProvider.notifier).state =
        _FiltrosFacturacion(desde: inicio, hasta: inicio.add(const Duration(days: 1)));
  }

  void _elegirSemana(WidgetRef ref) {
    final hoy = DateTime.now();
    final inicioSemana = DateTime(hoy.year, hoy.month, hoy.day).subtract(Duration(days: hoy.weekday - 1));
    ref.read(_filtrosFacturacionProvider.notifier).state =
        _FiltrosFacturacion(desde: inicioSemana, hasta: inicioSemana.add(const Duration(days: 7)));
  }

  void _elegirMes(WidgetRef ref) {
    final hoy = DateTime.now();
    ref.read(_filtrosFacturacionProvider.notifier).state = _FiltrosFacturacion(
      desde: DateTime(hoy.year, hoy.month, 1),
      hasta: DateTime(hoy.year, hoy.month + 1, 1),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(_filtrosFacturacionProvider);
    final itemsAsync = ref.watch(_facturacionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Elegir rango de fechas',
            onPressed: () => _elegirRangoPersonalizado(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_facturacionProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(label: const Text('Hoy'), onPressed: () => _elegirDia(ref)),
                    ActionChip(label: const Text('Esta semana'), onPressed: () => _elegirSemana(ref)),
                    ActionChip(label: const Text('Este mes'), onPressed: () => _elegirMes(ref)),
                    ActionChip(
                        label: const Text('Rango personalizado'),
                        onPressed: () => _elegirRangoPersonalizado(context, ref)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${Formatters.formatearFecha(filtros.desde)} — '
                  '${Formatters.formatearFecha(filtros.hasta.subtract(const Duration(days: 1)))}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No hubo movimientos por transferencia en este período.'));
                }
                final total = items.fold(0.0, (acc, i) => acc + i.montoBruto);
                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${items.length} movimiento(s) por transferencia',
                                style: TextStyle(color: Colors.grey.shade300)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total bruto'),
                                Text(
                                  Formatters.formatearMoneda(total),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total neto (÷ 1.105)'),
                                Text(
                                  Formatters.formatearMoneda(_montoNeto(total).toDouble()),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.green,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.check_circle, color: Colors.white),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Marcar como facturado'),
                                      content: const Text(
                                        '¿Marcar este movimiento como ya facturado? Va a desaparecer de '
                                        'esta lista, pero la venta o el pago siguen intactos en el resto '
                                        'de la app.',
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancelar')),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Marcar'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                            },
                            onDismissed: (_) async {
                              final usuarioId = ref.read(currentUserIdProvider);
                              await ref
                                  .read(facturacionMarcadoRepositoryProvider)
                                  .marcarComoFacturado(item.id, usuarioId);
                              ref.invalidate(_facturacionProvider);
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.receipt_long_rounded,
                                      size: 20, color: Theme.of(context).colorScheme.primary),
                                ),
                                title: Text(item.titulo),
                                subtitle: Text(
                                  '${item.subtitulo} · ${Formatters.formatearFechaHora(item.fecha)}',
                                  style: TextStyle(color: item.faltaCuitDni ? Colors.orange.shade300 : null),
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Bruto: ${Formatters.formatearMoneda(item.montoBruto)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                    Text(
                                      'Neto: ${Formatters.formatearMoneda(_montoNeto(item.montoBruto))}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, __) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
