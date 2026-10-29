import 'package:flutter/material.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/venta.dart';
import '../../../../domain/entities/detalle_venta.dart';
import '../../../../domain/entities/producto.dart';
import '../../../../domain/entities/cliente.dart';
import '../../../caja/widgets/metodo_pago_selector.dart';
import '../../../shared/widgets/loading_widget.dart';

/// Pantalla para editar el detalle (y la forma de pago) de una venta.
///
/// - Si la venta ya estaba COBRADA: se reconcilian stock y cuenta
///   corriente por la diferencia al guardar.
/// - Si la venta todavía está PENDIENTE (el vendedor la mandó, caja
///   todavía no la cobró): al guardar queda directamente COBRADA con
///   la forma de pago elegida acá — es una forma alternativa de cobrar
///   desde Historial, sin pasar por la pantalla normal de Caja.
///
/// En los dos casos la forma de pago admite dividir el total entre
/// varios métodos a la vez (ej: parte efectivo + parte fiado), igual
/// que al cobrar normalmente en Caja.
class EditarVentaScreen extends ConsumerStatefulWidget {
  final Venta venta;
  const EditarVentaScreen({super.key, required this.venta});

  @override
  ConsumerState<EditarVentaScreen> createState() => _EditarVentaScreenState();
}

class _EditarVentaScreenState extends ConsumerState<EditarVentaScreen> {
  late List<DetalleVenta> _items;
  late List<DetallePago> _pagos;
  Cliente? _clienteSeleccionado;
  String? _cuitDniComprador;
  bool _guardando = false;

  bool get _esPendiente => widget.venta.estado == EstadoVenta.pendiente;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.venta.detalle);
    _cuitDniComprador = widget.venta.cuitDniComprador;
    if (widget.venta.pagos.isNotEmpty) {
      _pagos = List.of(widget.venta.pagos);
    } else if (widget.venta.metodoPago != null) {
      _pagos = [DetallePago(metodo: widget.venta.metodoPago!, monto: widget.venta.total)];
    } else {
      _pagos = [];
    }
    _cargarClienteActual();
  }

  /// Si la venta ya tenía un cliente asignado (fiado o por
  /// transferencia), lo trae para mostrar su nombre (y poder
  /// reasignar a otro desde el mismo botón) en vez de solo el id.
  Future<void> _cargarClienteActual() async {
    final clienteId = widget.venta.clienteId;
    if (clienteId == null) return;
    final cliente = await ref.read(clienteRepositoryProvider).obtenerPorId(clienteId);
    if (mounted && cliente != null) setState(() => _clienteSeleccionado = cliente);
  }

  double get _total => _items.fold(0, (acc, d) => acc + d.precioTotal);

  double get _restante {
    final cargado = _pagos.fold<double>(0, (acc, p) => acc + p.monto);
    return _total - cargado;
  }

  bool get _incluyeCuentaCorriente => _pagos.any((p) => p.metodo == MetodoPago.cuentaCorriente);
  bool get _incluyeTransferencia => _pagos.any((p) => p.metodo == MetodoPago.transferencia);

  Future<void> _agregarPago() async {
    MetodoPago metodoElegido = MetodoPago.efectivo;
    final montoCtrl = TextEditingController(
        text: _restante > 0 ? _restante.toStringAsFixed(0) : _total.toStringAsFixed(0));

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
    final monto = Formatters.parsearMonto(montoCtrl.text);
    if (monto == null || monto <= 0) return;

    setState(() => _pagos.add(DetallePago(metodo: metodoElegido, monto: monto)));

    if (metodoElegido == MetodoPago.cuentaCorriente && _clienteSeleccionado == null) {
      await _elegirCliente();
    } else if (metodoElegido == MetodoPago.transferencia &&
        _clienteSeleccionado == null &&
        (_cuitDniComprador == null || _cuitDniComprador!.isEmpty)) {
      await _pedirCuitDniTransferencia();
    }
  }

  /// El contador necesita el CUIT/DNI de quien compra para poder
  /// facturar lo que se cobra por transferencia. Si no es un cliente ya
  /// registrado (con el dato guardado en su ficha), se pide acá mismo.
  Future<void> _pedirCuitDniTransferencia() async {
    final ctrl = TextEditingController(text: _cuitDniComprador ?? '');
    final resultado = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('CUIT o DNI del comprador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como se cobra por transferencia, el contador necesita este dato para poder facturar.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'CUIT o DNI', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _elegirCliente();
              },
              icon: const Icon(Icons.person_search),
              label: const Text('Es un cliente ya registrado'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (resultado != null && resultado.isNotEmpty) {
      setState(() => _cuitDniComprador = resultado);
    }
  }

  Future<void> _elegirCliente() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const LoadingWidget());
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
    clientes.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    final elegido = await showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String busqueda = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtrados = busqueda.isEmpty
                ? clientes
                : clientes.where((c) => c.nombre.toLowerCase().contains(busqueda.toLowerCase())).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: TextField(
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Buscar cliente...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setSheetState(() => busqueda = v),
                        ),
                      ),
                      Expanded(
                        child: filtrados.isEmpty
                            ? const Center(child: Text('Ningún cliente coincide con la búsqueda.'))
                            : ListView(
                                children: filtrados
                                    .map((c) => ListTile(
                                          title: Text(c.nombre),
                                          subtitle: Text(Formatters.formatearMoneda(c.saldoCuentaCorriente)),
                                          onTap: () => Navigator.pop(context, c),
                                        ))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (elegido != null) setState(() => _clienteSeleccionado = elegido);
  }

  Future<void> _agregarOEditarItem({DetalleVenta? existente}) async {
    final productos = await ref.read(productoRepositoryProvider).obtenerTodos();
    Producto? productoSeleccionado;
    final productoLibreNombre = existente?.nombreProducto;
    final cantidadCtrl =
        TextEditingController(text: existente != null ? Formatters.formatearCantidad(existente.cantidad) : '');
    final precioCtrl = TextEditingController(
        text: existente != null && existente.cantidad > 0
            ? (existente.precioTotal / existente.cantidad).toStringAsFixed(0)
            : '');

    final resultado = await showDialog<DetalleVenta>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cantidad = double.tryParse(cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
          final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;
          final totalItem = cantidad * precio;
          return AlertDialog(
            title: Text(existente != null ? 'Editar producto' : 'Agregar producto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existente == null)
                    DropdownButtonFormField<Producto>(
                      initialValue: productoSeleccionado,
                      decoration:
                          const InputDecoration(labelText: 'Producto', border: OutlineInputBorder()),
                      items: productos.map((p) => DropdownMenuItem(value: p, child: Text(p.nombre))).toList(),
                      onChanged: (p) => setDialogState(() => productoSeleccionado = p),
                    )
                  else
                    Text(productoLibreNombre ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: precioCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Precio por unidad', border: OutlineInputBorder()),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.secondary),
                    ),
                    child: Text(
                      'Total: ${Formatters.formatearMoneda(totalItem)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final cant = double.tryParse(cantidadCtrl.text.replaceAll(',', '.'));
                  final prec = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
                  final nombreFinal = existente?.nombreProducto ?? productoSeleccionado?.nombre;
                  final idFinal = existente?.productoId ?? productoSeleccionado?.id;
                  if (cant == null || cant <= 0 || prec == null || prec < 0 || nombreFinal == null || idFinal == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Completá producto, cantidad y precio correctamente')),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    DetalleVenta(
                      productoId: idFinal,
                      nombreProducto: nombreFinal,
                      cantidad: cant,
                      precioTotal: cant * prec,
                    ),
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (resultado == null) return;
    setState(() {
      if (existente != null) {
        final idx = _items.indexOf(existente);
        if (idx != -1) _items[idx] = resultado;
      } else {
        _items.add(resultado);
      }
    });
  }

  void _quitarItem(DetalleVenta item) {
    setState(() => _items.remove(item));
  }

  String _labelMetodo(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.transferencia => 'Transferencia',
        MetodoPago.debito => 'Débito',
        MetodoPago.credito => 'Crédito',
        MetodoPago.cuentaCorriente => 'Cuenta corriente',
      };

  Future<void> _guardar() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La venta tiene que tener al menos un producto')),
      );
      return;
    }
    if (_pagos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregá al menos un método de pago')),
      );
      return;
    }
    if (_restante.abs() > 0.5) {
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
    if (_incluyeTransferencia &&
        _clienteSeleccionado == null &&
        (_cuitDniComprador == null || _cuitDniComprador!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta el CUIT/DNI de quién compra por transferencia')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final usuarioId = ref.read(currentUserIdProvider);
      if (_esPendiente) {
        // Todavía no estaba cobrada: guardar acá la cobra directo con
        // la forma de pago elegida (mismo caso de uso que usa Caja).
        await ref.read(finalizarCobroUseCaseProvider).call(
              widget.venta.copyWith(detalle: _items, total: _total),
              usuarioId,
              _pagos,
              clienteId: _clienteSeleccionado?.id,
              cuitDniComprador: _cuitDniComprador,
            );
      } else {
        await ref.read(editarVentaUseCaseProvider).call(
              widget.venta,
              _items,
              _pagos,
              usuarioId,
              nuevoClienteId: _clienteSeleccionado?.id,
            );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: Text('Editar venta #${widget.venta.numero}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _agregarOEditarItem(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _esPendiente
                  ? 'Esta venta todavía no se cobró: al guardar, queda cobrada directo con la forma de pago que elijas acá.'
                  : 'Esta venta ya está cobrada: el stock y la cuenta corriente (si había parte fiada) '
                      'se van a ajustar automáticamente por la diferencia.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade300),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final item in _items)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      title: Text(item.nombreProducto),
                      subtitle: Text('Cantidad: ${Formatters.formatearCantidad(item.cantidad)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Formatters.formatearMoneda(item.precioTotal)),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _agregarOEditarItem(existente: item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _quitarItem(item),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Forma de pago', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      const SizedBox(height: 4),
                      Text(
                        _restante.abs() < 0.5
                            ? 'Pagos completos'
                            : (_restante > 0
                                ? 'Falta cubrir: ${Formatters.formatearMoneda(_restante)}'
                                : 'Sobran: ${Formatters.formatearMoneda(-_restante)}'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _restante.abs() < 0.5 ? Colors.green : Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _restante.abs() < 0.5 ? null : _agregarPago,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar pago'),
                      ),
                      if (_incluyeCuentaCorriente) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _elegirCliente,
                          icon: const Icon(Icons.person),
                          label: Text(_clienteSeleccionado?.nombre ?? 'Elegir cliente para la parte fiada'),
                        ),
                      ],
                      if (_incluyeTransferencia) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _pedirCuitDniTransferencia,
                          icon: const Icon(Icons.badge_outlined),
                          label: Text(
                            _clienteSeleccionado != null
                                ? 'Cliente: ${_clienteSeleccionado!.nombre}'
                                : (_cuitDniComprador != null && _cuitDniComprador!.isNotEmpty
                                    ? 'CUIT/DNI: ${_cuitDniComprador!}'
                                    : 'Falta CUIT/DNI para la transferencia'),
                          ),
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(
                      Formatters.formatearMoneda(_total),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_esPendiente ? 'Cobrar venta' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
