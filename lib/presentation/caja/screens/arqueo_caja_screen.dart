import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/dia_laboral_service.dart';
import '../../../domain/entities/caja.dart';
import '../../../domain/entities/venta.dart';
import 'historial_cierres_screen.dart';

/// Denominaciones de billetes en pesos argentinos, tal como se cuentan
/// en la planilla (de mayor a menor).
const _denominaciones = [20000, 10000, 2000, 1000, 500, 100, 50];

/// Cuántos billetes tiene un "fajo" en este negocio (ej: un fajo de
/// $20.000 son 100 billetes = $2.000.000). Se usa para la "caja
/// grande", donde se cuenta en fajos en vez de billete por billete.
const _billetesPorFajo = 100;

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
  final rango = await DiaLaboralService.rangoDeHoy();
  final ventas =
      await ref.watch(ventaRepositoryProvider).obtenerPorRangoFechaGlobal(rango.inicio, rango.fin);
  return ventas.where((v) => v.estado == EstadoVenta.cobrada).toList();
});

/// Nombre real de cada cliente registrado (para mostrar en vez de
/// "Fiado" en el desplegable de cuenta corriente).
final _nombresClientesProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final clientes = await ref.watch(clienteRepositoryProvider).obtenerTodos();
  return {for (final c in clientes) c.id: c.nombre};
});

/// Movimientos manuales de caja de hoy (ingresos/egresos aparte de ventas).
final _movimientosCajaHoyProvider = FutureProvider.autoDispose<List<MovimientoCaja>>((ref) async {
  final rango = await DiaLaboralService.rangoDeHoy();
  return ref.watch(cajaRepositoryProvider).obtenerMovimientos(rango.inicio, rango.fin);
});

/// El rango del día laboral actual, para mostrarlo en pantalla.
final _rangoDiaLaboralProvider =
    FutureProvider.autoDispose<({DateTime inicio, DateTime fin})>((ref) => DiaLaboralService.rangoDeHoy());

/// Marca especial en el detalle para reconocer el ingreso que representa
/// la "caja inicio" del día (el efectivo con el que arrancó la jornada),
/// para poder guardarlo, mostrarlo aparte, y no contarlo dos veces
/// dentro de "Ingresos manuales".
const _detalleCajaInicio = 'Caja inicio';

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
  static const _claveBorrador = 'arqueo_caja_borrador_conteo';

  final _cajaInicioCtrl = TextEditingController(text: '0');
  final Map<int, TextEditingController> _billeteCtrls = {
    for (final d in _denominaciones) d: TextEditingController(text: '0'),
  };
  final Map<int, TextEditingController> _fajoCtrls = {
    for (final d in _denominaciones) d: TextEditingController(text: '0'),
  };
  bool _guardando = false;
  bool _guardandoCajaInicio = false;
  bool _cajaInicioYaCargada = false; // para no pisar lo que el cajero está escribiendo

  @override
  void initState() {
    super.initState();
    _cargarBorrador();
    // Cualquier cambio en los contadores de billetes (chica o grande)
    // se guarda como borrador, para que no se pierda si el cajero sale
    // de esta pantalla sin llegar a cerrar la caja todavía.
    for (final c in _billeteCtrls.values) {
      c.addListener(_guardarBorrador);
    }
    for (final c in _fajoCtrls.values) {
      c.addListener(_guardarBorrador);
    }
  }

  Future<void> _cargarBorrador() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_claveBorrador);
    if (guardado == null) return;
    try {
      final data = jsonDecode(guardado) as Map<String, dynamic>;
      final sueltos = (data['sueltos'] as Map<String, dynamic>?) ?? {};
      final fajos = (data['fajos'] as Map<String, dynamic>?) ?? {};
      for (final d in _denominaciones) {
        final valorSuelto = sueltos[d.toString()];
        if (valorSuelto != null) _billeteCtrls[d]!.text = valorSuelto.toString();
        final valorFajo = fajos[d.toString()];
        if (valorFajo != null) _fajoCtrls[d]!.text = valorFajo.toString();
      }
    } catch (_) {
      // Borrador corrupto o de un formato viejo: se ignora, arranca en 0.
    }
  }

  Future<void> _guardarBorrador() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'sueltos': {for (final d in _denominaciones) d.toString(): _billeteCtrls[d]!.text},
      'fajos': {for (final d in _denominaciones) d.toString(): _fajoCtrls[d]!.text},
    };
    await prefs.setString(_claveBorrador, jsonEncode(data));
  }

  Future<void> _borrarBorrador() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveBorrador);
  }

  /// Guarda (o actualiza, si ya había uno hoy) el ingreso especial que
  /// representa la caja inicio del día. Es siempre en efectivo.
  Future<void> _guardarCajaInicio(List<MovimientoCaja> movimientosActuales) async {
    final monto = double.tryParse(_cajaInicioCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un monto válido')),
      );
      return;
    }
    setState(() => _guardandoCajaInicio = true);
    try {
      // Si el cajero ya había cargado una caja inicio hoy y se equivocó,
      // esto la reemplaza en vez de duplicarla.
      final existente = movimientosActuales.where((m) => m.detalle == _detalleCajaInicio);
      for (final m in existente) {
        await ref.read(cajaRepositoryProvider).eliminarMovimiento(m.id);
      }
      final usuarioId = ref.read(currentUserIdProvider);
      await ref.read(cajaRepositoryProvider).registrarMovimiento(
            tipo: TipoMovimientoCaja.ingreso,
            monto: monto,
            detalle: _detalleCajaInicio,
            usuarioId: usuarioId,
          );
      ref.invalidate(_movimientosCajaHoyProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Caja inicio guardada: ${Formatters.formatearMoneda(monto)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoCajaInicio = false);
    }
  }

  @override
  void dispose() {
    _cajaInicioCtrl.dispose();
    for (final c in _billeteCtrls.values) {
      c.dispose();
    }
    for (final c in _fajoCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalCajaChica {
    double total = 0;
    for (final d in _denominaciones) {
      final cantidad = int.tryParse(_billeteCtrls[d]!.text) ?? 0;
      total += d * cantidad;
    }
    return total;
  }

  double get _totalCajaGrande {
    double total = 0;
    for (final d in _denominaciones) {
      final cantidadFajos = int.tryParse(_fajoCtrls[d]!.text) ?? 0;
      total += d * cantidadFajos * _billetesPorFajo;
    }
    return total;
  }

  double get _totalContado => _totalCajaChica + _totalCajaGrande;

  Future<void> _cerrarCaja() async {
    setState(() => _guardando = true);
    try {
      final usuarioId = ref.read(currentUserIdProvider);
      // El cierre guardado combina la caja chica (billetes sueltos) y
      // la caja grande (fajos, convertidos a su cantidad equivalente de
      // billetes) en un solo conteo por denominación — así no hace
      // falta cambiar cómo se guarda el cierre.
      final billetes = _denominaciones.map((d) {
        final sueltos = int.tryParse(_billeteCtrls[d]!.text) ?? 0;
        final fajos = int.tryParse(_fajoCtrls[d]!.text) ?? 0;
        return ConteoBillete(denominacion: d, cantidad: sueltos + (fajos * _billetesPorFajo));
      }).where((b) => b.cantidad > 0).toList();
      await ref.read(cajaRepositoryProvider).guardarCierre(
            cajaInicio: double.tryParse(_cajaInicioCtrl.text.replaceAll(',', '.')) ?? 0,
            billetes: billetes,
            usuarioId: usuarioId,
          );
      await _borrarBorrador();
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
    // Los egresos son siempre en efectivo (no tiene sentido "un gasto
    // por transferencia" para el arqueo físico). Los ingresos casi
    // siempre son en efectivo también, pero a veces te transfieren en
    // vez de traer el efectivo — por eso solo a los ingresos se les
    // pregunta el método.
    MetodoMovimientoCaja metodo = MetodoMovimientoCaja.efectivo;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
              if (tipo == TipoMovimientoCaja.ingreso) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('¿Cómo entró la plata?', style: TextStyle(color: Colors.grey.shade400)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: MetodoMovimientoCaja.values.map((m) {
                    return ChoiceChip(
                      label: Text(m == MetodoMovimientoCaja.efectivo ? 'Efectivo' : 'Transferencia'),
                      selected: metodo == m,
                      onSelected: (_) => setDialogState(() => metodo = m),
                    );
                  }).toList(),
                ),
              ],
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
    final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) return;

    final usuarioId = ref.read(currentUserIdProvider);
    await ref.read(cajaRepositoryProvider).registrarMovimiento(
          tipo: tipo,
          monto: monto,
          detalle: detalleCtrl.text.trim().isEmpty ? '(sin detalle)' : detalleCtrl.text.trim(),
          usuarioId: usuarioId,
          // Los egresos quedan siempre en efectivo, sin preguntar.
          metodo: tipo == TipoMovimientoCaja.egreso ? MetodoMovimientoCaja.efectivo : metodo,
        );
    ref.invalidate(_movimientosCajaHoyProvider);
  }

  /// Separa cada venta cobrada hoy en ítems por método de pago (una
  /// venta con pago dividido aparece una vez por cada parte), y
  /// devuelve los dos grupos que nos interesan: efectivo, y
  /// cuenta corriente (fiado + transferencia juntos).
  ({List<_ItemVentaCaja> efectivo, List<_ItemVentaCaja> cuentaCorriente}) _agruparVentas(
      List<Venta> ventas, Map<String, String> nombresClientes) {
    final efectivo = <_ItemVentaCaja>[];
    final cuentaCorriente = <_ItemVentaCaja>[];

    for (final v in ventas) {
      final pagos = v.pagos.isNotEmpty
          ? v.pagos
          : (v.metodoPago != null ? [DetallePago(metodo: v.metodoPago!, monto: v.total)] : <DetallePago>[]);

      for (final p in pagos) {
        // Para lo fiado, mostrar el nombre real del cliente registrado
        // (no "Fiado") — para transferencia sí tiene sentido decir
        // "Transferencia", ya que puede no haber un cliente vinculado.
        final metodoLabel = p.metodo == MetodoPago.cuentaCorriente
            ? (nombresClientes[v.clienteId] ?? v.nombreCliente ?? 'Fiado')
            : _labelMetodo(p.metodo);
        final item = _ItemVentaCaja(
          numero: v.numero,
          nombreCliente: v.nombreCliente,
          monto: p.monto,
          metodoLabel: metodoLabel,
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

  Future<void> _editarHoraCorte() async {
    final horaActual = await DiaLaboralService.obtenerHoraCorte();
    if (!mounted) return;
    int horaElegida = horaActual;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Hora de corte del día'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A esta hora "termina" el día anterior y arranca el día '
                'nuevo (para Arqueo de Caja y Estadísticas). Útil si se '
                'trabaja de noche hasta la mañana siguiente.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: horaElegida,
                decoration: const InputDecoration(labelText: 'Hora de corte', border: OutlineInputBorder()),
                items: List.generate(24, (h) => h)
                    .map((h) => DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')))
                    .toList(),
                onChanged: (h) => setDialogState(() => horaElegida = h ?? horaElegida),
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
    if (confirmado == true) {
      await DiaLaboralService.guardarHoraCorte(horaElegida);
      ref.invalidate(_rangoDiaLaboralProvider);
      ref.invalidate(_ventasHoyProvider);
      ref.invalidate(_movimientosCajaHoyProvider);
    }
  }

  Widget _carteRangoDiaLaboral() {
    final rangoAsync = ref.watch(_rangoDiaLaboralProvider);
    return rangoAsync.when(
      data: (rango) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Mostrando'),
          subtitle: Text(
            '${Formatters.formatearFechaHora(rango.inicio)} — ${Formatters.formatearFechaHora(rango.fin)}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: 'Cambiar hora de corte del día',
            onPressed: _editarHoraCorte,
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
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
          _carteRangoDiaLaboral(),
          ventasAsync.when(
            data: (ventas) => movimientosAsync.when(
              data: (movimientos) {
                // Precarga el campo con la caja inicio ya guardada hoy,
                // una sola vez (para no pisar lo que el cajero esté
                // escribiendo si todavía no la guardó).
                if (!_cajaInicioYaCargada) {
                  final existente = movimientos.where((m) => m.detalle == _detalleCajaInicio);
                  if (existente.isNotEmpty) {
                    _cajaInicioCtrl.text = existente.first.monto.toStringAsFixed(0);
                  }
                  _cajaInicioYaCargada = true;
                }

                final movimientosSinCajaInicio =
                    movimientos.where((m) => m.detalle != _detalleCajaInicio).toList();
                final ingresosTodos = movimientosSinCajaInicio.where((m) => m.tipo == TipoMovimientoCaja.ingreso).toList();
                final egresosTodos = movimientosSinCajaInicio.where((m) => m.tipo == TipoMovimientoCaja.egreso).toList();
                final nombresClientes = ref.watch(_nombresClientesProvider).valueOrNull ?? {};
                final grupos = _agruparVentas(ventas, nombresClientes);
                final totalEfectivo = grupos.efectivo.fold(0.0, (acc, i) => acc + i.monto);
                final ingresosEfectivo = ingresosTodos
                    .where((m) => m.metodo == MetodoMovimientoCaja.efectivo)
                    .fold(0.0, (acc, m) => acc + m.monto);
                final ingresosTransferencia = ingresosTodos
                    .where((m) => m.metodo == MetodoMovimientoCaja.transferencia)
                    .fold(0.0, (acc, m) => acc + m.monto);
                // Cuenta corriente agrupa: fiado + transferencia (ventas)
                // + ingresos manuales que llegaron por transferencia —
                // ninguno de esos casos mete plata física a la caja.
                final totalCuentaCorriente =
                    grupos.cuentaCorriente.fold(0.0, (acc, i) => acc + i.monto) + ingresosTransferencia;
                final egresos = egresosTodos.fold(0.0, (acc, m) => acc + m.monto);
                final cajaInicio = double.tryParse(_cajaInicioCtrl.text.replaceAll(',', '.')) ?? 0;
                // La cuenta corriente (fiado + transferencia) NO suma al
                // efectivo esperado: esa plata no entró físicamente a la
                // caja como billetes, se muestra solo a modo informativo.
                final totalEsperado = cajaInicio + totalEfectivo + ingresosEfectivo - egresos;
                final diferencia = _totalContado - totalEsperado;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _cajaInicioCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Caja inicio (efectivo)',
                        border: const OutlineInputBorder(),
                        suffixIcon: _guardandoCajaInicio
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  height: 16, width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.save),
                                tooltip: 'Guardar caja inicio',
                                onPressed: () => _guardarCajaInicio(movimientos),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _filaResumen('Caja inicio', cajaInicio),
                            _filaResumen('Ventas en efectivo hoy', totalEfectivo),
                            _filaResumen('Ventas en cuenta corriente hoy (fiado + transferencia)',
                                totalCuentaCorriente),
                            _filaResumen('Ingresos manuales (efectivo)', ingresosEfectivo),
                            _filaResumen('Egresos manuales', -egresos),
                            const Divider(),
                            _filaResumen('Total esperado en caja', totalEsperado, negrita: true),
                            _filaResumen('Total contado (caja chica + caja grande)', _totalContado, negrita: true),
                            const Divider(),
                            _filaResumen('Diferencia', diferencia,
                                negrita: true, colorSegunSigno: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _desplegableVentas('Ventas en efectivo', grupos.efectivo, Colors.green.shade300),
                    const SizedBox(height: 8),
                    _desplegableVentas(
                        'Ventas en cuenta corriente (fiado + transferencia)',
                        grupos.cuentaCorriente,
                        Colors.blue.shade200),
                    const SizedBox(height: 8),
                    _desplegableMovimientos('Ingresos', ingresosTodos, Colors.teal.shade300),
                    const SizedBox(height: 8),
                    _desplegableMovimientos('Egresos', egresosTodos, Colors.red.shade300),
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
          Card(
            child: ExpansionTile(
              title: const Text('Caja grande (fajos)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Subtotal: ${Formatters.formatearMoneda(_totalCajaGrande)}'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Un fajo de cada denominación equivale a $_billetesPorFajo billetes.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: _denominaciones
                        .map((d) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(width: 90, child: Text(Formatters.formatearMoneda(d))),
                                  Expanded(
                                    child: TextField(
                                      controller: _fajoCtrls[d],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Cantidad de fajos',
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
                                      Formatters.formatearMoneda(d *
                                          (int.tryParse(_fajoCtrls[d]!.text) ?? 0) *
                                          _billetesPorFajo),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              title: const Text('Caja chica (billetes sueltos)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Subtotal: ${Formatters.formatearMoneda(_totalCajaChica)}'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: _denominaciones
                        .map((d) => Padding(
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
                                      Formatters.formatearMoneda(
                                          d * (int.tryParse(_billeteCtrls[d]!.text) ?? 0)),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
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
    final color = colorSegunSigno ? (valor >= 0 ? Colors.green.shade300 : Colors.red.shade300) : null;
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

  Widget _desplegableMovimientos(String titulo, List<MovimientoCaja> items, Color color) {
    final total = items.fold(0.0, (acc, m) => acc + m.monto);
    return Card(
      child: ExpansionTile(
        title: Text(titulo),
        subtitle: Text('${items.length} movimiento(s) · ${Formatters.formatearMoneda(total)}'),
        children: items.isEmpty
            ? [Padding(padding: const EdgeInsets.all(16), child: Text('Sin ${titulo.toLowerCase()} todavía hoy.'))]
            : items
                .map((m) => Dismissible(
                      key: ValueKey(m.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        await ref.read(cajaRepositoryProvider).eliminarMovimiento(m.id);
                        ref.invalidate(_movimientosCajaHoyProvider);
                      },
                      child: ListTile(
                        dense: true,
                        title: Text(m.detalle),
                        subtitle: Text(
                          '${m.metodo == MetodoMovimientoCaja.efectivo ? 'Efectivo' : 'Transferencia'} · '
                          '${Formatters.formatearHora(m.fecha)}',
                        ),
                        trailing: Text(
                          Formatters.formatearMoneda(m.monto),
                          style: TextStyle(fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                    ))
                .toList(),
      ),
    );
  }
}
