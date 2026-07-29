import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../domain/entities/producto.dart';

/// Formulario para crear/editar un producto: nombre, activo/inactivo, y
/// el costo por unidad (para el reporte de utilidad). Ya no pide
/// "categoría" (todo el catálogo es del mismo rubro, no aportaba nada)
/// ni "precio sugerido" (el vendedor ya ve el costo de referencia al
/// armar la venta). IIBB y TSH tampoco se cargan acá: se calculan solos
/// como porcentaje de la venta (configurable desde Estadísticas), igual
/// que en la planilla de control diario.
class ProductoFormScreen extends ConsumerStatefulWidget {
  final Producto? producto; // null = creación

  const ProductoFormScreen({super.key, this.producto});

  @override
  ConsumerState<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends ConsumerState<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _costoCtrl;
  bool _activo = true;
  bool _guardando = false;

  bool get _esEdicion => widget.producto != null;

  String _num(double v) => v > 0 ? v.toStringAsFixed(0) : '';

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _costoCtrl = TextEditingController(text: p != null ? _num(p.costoUnitario) : '');
    _activo = p?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  double _leer(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final producto = Producto(
        id: widget.producto?.id ?? const Uuid().v4(),
        nombre: _nombreCtrl.text.trim(),
        precioSugerido: 0, // ya no se carga por producto (queda el costo como referencia)
        categoria: widget.producto?.categoria ?? 'Verduras', // ya no se elige por producto
        activo: _activo,
        costoUnitario: _leer(_costoCtrl),
      );

      final usecase = ref.read(gestionarProductosUseCaseProvider);
      if (_esEdicion) {
        await usecase.actualizar(producto);
      } else {
        await usecase.crear(producto);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar producto' : 'Nuevo producto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                validator: (v) => Validators.requerido(v, campo: 'El nombre'),
              ),
              const SizedBox(height: 20),
              const Text('Costo (para el reporte de utilidad)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'IIBB y TSH ya no se cargan por producto: se calculan solos como '
                'porcentaje de la venta. Podés ajustar esos porcentajes desde '
                'Estadísticas si hace falta.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _costoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Costo por unidad',
                  border: OutlineInputBorder(),
                  helperText: 'Lo que pagás vos por cada bulto/unidad',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Activo'),
                subtitle: const Text('Los productos inactivos no aparecen en la búsqueda del vendedor'),
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_esEdicion ? 'Guardar cambios' : 'Crear producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
