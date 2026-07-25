import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../domain/entities/producto.dart';

/// Pantalla para hacer un ajuste manual de stock (corrección de inventario).
class AjusteStockScreen extends ConsumerStatefulWidget {
  final Producto producto;
  final double cantidadActual;
  const AjusteStockScreen({super.key, required this.producto, required this.cantidadActual});

  @override
  ConsumerState<AjusteStockScreen> createState() => _AjusteStockScreenState();
}

class _AjusteStockScreenState extends ConsumerState<AjusteStockScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cantidadCtrl;
  final _notaCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cantidadCtrl = TextEditingController(text: widget.cantidadActual.toStringAsFixed(0));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final nuevaCantidad = double.parse(_cantidadCtrl.text.replaceAll(',', '.'));
      final usuarioId = ref.read(currentUserIdProvider);
      await ref.read(ajusteManualStockUseCaseProvider).call(
            widget.producto.id,
            nuevaCantidad,
            usuarioId,
            nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajuste: ${widget.producto.nombre}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('Stock actual: ${widget.cantidadActual}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cantidadCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Cantidad correcta', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresá la cantidad correcta';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null) return 'Debe ser un número';
                  if (n < 0) return 'No puede ser negativo';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Motivo del ajuste (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar ajuste'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
