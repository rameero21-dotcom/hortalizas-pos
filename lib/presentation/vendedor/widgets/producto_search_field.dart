import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/detalle_venta.dart';
import '../../../domain/entities/producto.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import '../providers/carrito_provider.dart';

/// Cómo se interpreta el número que carga el vendedor en el campo de precio.
enum _ModoPrecio { total, unitario }

/// Buscador de productos con lista desplegable + campos de cantidad y
/// precio (total o por unidad, con cálculo automático) + botón Agregar.
/// Si el producto buscado no existe, permite darlo de alta al toque sin
/// salir de la pantalla de venta.
///
/// Carga el catálogo completo de productos activos una sola vez
/// (catálogo chico, típico de un comercio de hortalizas) y filtra
/// localmente a medida que se escribe, sin golpear la base en cada tecla.
class ProductoSearchField extends ConsumerStatefulWidget {
  const ProductoSearchField({super.key});

  @override
  ConsumerState<ProductoSearchField> createState() => _ProductoSearchFieldState();
}

class _ProductoSearchFieldState extends ConsumerState<ProductoSearchField> {
  final _busquedaCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _busquedaFocus = FocusNode();

  List<Producto> _productos = [];
  List<Producto> _filtrados = [];
  Producto? _productoSeleccionado;
  bool _cargando = true;
  String? _error;
  _ModoPrecio _modoPrecio = _ModoPrecio.total;
  bool _ignorarProximoCambioDeTexto = false; // ver _seleccionar()

  @override
  void initState() {
    super.initState();
    _cargarInicial();
    _busquedaFocus.addListener(() {
      if (_busquedaFocus.hasFocus) {
        setState(() {});
      } else {
        // No ocultar la lista al instante: con mouse (Windows), el
        // campo puede perder el foco un momento ANTES de que el clic
        // sobre un ítem de la lista termine de procesarse, y si la
        // ocultamos ya mismo, ese ítem desaparece a mitad del clic y
        // nunca llega a seleccionarse. Este pequeño margen le da tiempo
        // al clic para completarse primero.
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && !_busquedaFocus.hasFocus) setState(() {});
        });
      }
    });
  }

  /// Al abrir la pantalla, primero intenta traer los cambios desde
  /// Firestore (productos nuevos, eliminados o editados desde Admin) y
  /// recién después muestra la lista — así el vendedor ve el catálogo
  /// al día sin tener que acordarse de tocar "actualizar" a mano.
  Future<void> _cargarInicial() async {
    try {
      await ref.read(productoRepositoryProvider).refrescarDesdeRemoto();
    } catch (_) {
      // Sin conexión: seguimos con lo que haya en la caché local.
    }
    await _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final productos = await ref.read(productoRepositoryProvider).obtenerTodos();
      if (!mounted) return;
      final activos = productos.where((p) => p.activo).toList()
        ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      setState(() {
        _productos = activos;
        _filtrados = _productos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los productos';
        _cargando = false;
      });
    }
  }

  void _filtrar(String query) {
    setState(() {
      _filtrados = query.isEmpty
          ? _productos
          : _productos.where((p) => p.nombre.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _seleccionar(Producto producto) {
    // Escribir el nombre en el campo dispara el "onChanged" del
    // TextField (aunque el cambio sea programático, no tipeado por el
    // usuario) — sin esta bandera, ese onChanged deshacía la selección
    // que se acababa de hacer, un instante después, en el mismo cuadro.
    _ignorarProximoCambioDeTexto = true;
    setState(() {
      _productoSeleccionado = producto;
      _busquedaCtrl.text = producto.nombre;
    });
    _busquedaFocus.unfocus();
  }

  /// Calcula el precio TOTAL a partir de lo que cargó el vendedor, según el
  /// modo elegido: si es "unitario", multiplica por la cantidad.
  double? _calcularPrecioTotal(double cantidad) {
    final valor = double.tryParse(_precioCtrl.text.replaceAll(',', '.'));
    if (valor == null) return null;
    return _modoPrecio == _ModoPrecio.unitario ? valor * cantidad : valor;
  }

  void _agregar() {
    final cantidad = double.tryParse(_cantidadCtrl.text.replaceAll(',', '.'));
    if (_productoSeleccionado == null || cantidad == null || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí un producto y una cantidad mayor a cero')),
      );
      return;
    }
    final precioTotal = _calcularPrecioTotal(cantidad);
    if (precioTotal == null || precioTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un precio mayor a cero')),
      );
      return;
    }

    ref.read(carritoProvider.notifier).agregarProducto(DetalleVenta(
          productoId: _productoSeleccionado!.id,
          nombreProducto: _productoSeleccionado!.nombre,
          cantidad: cantidad,
          precioTotal: precioTotal,
        ));

    setState(() {
      _productoSeleccionado = null;
      _busquedaCtrl.clear();
      _cantidadCtrl.clear();
      _precioCtrl.clear();
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _busquedaFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mostrarDropdown = _busquedaFocus.hasFocus && _productoSeleccionado == null;

    return Column(
      children: [
        TextField(
          controller: _busquedaCtrl,
          focusNode: _busquedaFocus,
          onChanged: (v) {
            if (_ignorarProximoCambioDeTexto) {
              _ignorarProximoCambioDeTexto = false;
              return;
            }
            if (_productoSeleccionado != null) setState(() => _productoSeleccionado = null);
            _filtrar(v);
          },
          decoration: InputDecoration(
            labelText: 'Buscar producto',
            border: const OutlineInputBorder(),
            suffixIcon: _cargando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.search),
          ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!)),
        if (mostrarDropdown && !_cargando)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: _filtrados.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Sin resultados. Pedile a un administrador que lo cargue.'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filtrados.length,
                          itemBuilder: (context, i) {
                            final p = _filtrados[i];
                            return ListTile(
                              title: Text(p.nombre),
                              subtitle: Text(p.categoria),
                              onTap: () => _seleccionar(p),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (_productoSeleccionado != null && _productoSeleccionado!.costoUnitario > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                border: Border.all(color: Theme.of(context).colorScheme.secondary),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '💰  Costo de referencia: ${Formatters.formatearMoneda(_productoSeleccionado!.costoUnitario)} por unidad',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cantidadCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _precioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _modoPrecio == _ModoPrecio.total ? 'Precio total' : 'Precio por unidad',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<_ModoPrecio>(
          segments: const [
            ButtonSegment(value: _ModoPrecio.total, label: Text('Precio total')),
            ButtonSegment(value: _ModoPrecio.unitario, label: Text('Precio por unidad')),
          ],
          selected: {_modoPrecio},
          onSelectionChanged: (nuevo) => setState(() => _modoPrecio = nuevo.first),
        ),
        if (_modoPrecio == _ModoPrecio.unitario)
          Builder(builder: (context) {
            final cantidad = double.tryParse(_cantidadCtrl.text.replaceAll(',', '.'));
            final total = cantidad != null ? _calcularPrecioTotal(cantidad) : null;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  total != null ? 'Total calculado: \$${total.toStringAsFixed(0)}' : 'Total calculado: —',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _agregar,
          icon: const Icon(Icons.add),
          label: const Text('Agregar'),
        ),
      ],
    );
  }
}
