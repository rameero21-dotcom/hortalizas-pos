import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/detalle_venta.dart';
import '../../../domain/entities/producto.dart';
import '../../../core/di/providers.dart';
import '../providers/carrito_provider.dart';

/// Buscador de productos con lista desplegable + campos de cantidad
/// y precio TOTAL (no unitario) + botón Agregar.
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

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _busquedaFocus.addListener(() => setState(() {}));
  }

  Future<void> _cargarProductos() async {
    try {
      final productos = await ref.read(productoRepositoryProvider).obtenerTodos();
      if (!mounted) return;
      setState(() {
        _productos = productos.where((p) => p.activo).toList();
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
    setState(() {
      _productoSeleccionado = producto;
      _busquedaCtrl.text = producto.nombre;
    });
    _busquedaFocus.unfocus();
  }

  void _agregar() {
    final cantidad = double.tryParse(_cantidadCtrl.text.replaceAll(',', '.'));
    final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.'));
    if (_productoSeleccionado == null || cantidad == null || precio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí un producto, cantidad y precio válidos')),
      );
      return;
    }

    ref.read(carritoProvider.notifier).agregarProducto(DetalleVenta(
          productoId: _productoSeleccionado!.id,
          nombreProducto: _productoSeleccionado!.nombre,
          cantidad: cantidad,
          precioTotal: precio,
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
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: _filtrados.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Sin resultados. Podés cargarlo en Admin > Productos.'),
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cantidadCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _precioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio total', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
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
