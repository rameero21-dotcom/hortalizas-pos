import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../domain/entities/producto.dart';

/// Pantalla para registrar ingreso de mercadería (aumenta stock).
class IngresoMercaderiaScreen extends ConsumerStatefulWidget {
  final Producto producto;
  const IngresoMercaderiaScreen({super.key, required this.producto});

  @override
  ConsumerState<IngresoMercaderiaScreen> createState() => _IngresoMercaderiaScreenState();
}

class _IngresoMercaderiaScreenState extends ConsumerState<IngresoMercaderiaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  bool _guardando = false;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final cantidad = double.parse(_cantidadCtrl.text.replaceAll(',', '.'));
      final usuarioId = ref.read(currentUserIdProvider);
      await ref.read(ingresarMercaderiaUseCaseProvider).call(
            widget.producto.id,
            cantidad,
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
      appBar: AppBar(title: Text('Ingreso: ${widget.producto.nombre}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _cantidadCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Cantidad que ingresa', border: OutlineInputBorder()),
                validator: (v) => Validators.numeroPositivo(v, campo: 'La cantidad'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nota (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Registrar ingreso'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
