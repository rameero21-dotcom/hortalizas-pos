import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../domain/entities/producto.dart';

/// Registra una pérdida/descarte de mercadería (producto que se echó a
/// perder, se rompió, etc.) — equivalente a la fila "MERMA" de la
/// planilla de control diario. Descuenta del stock igual que una venta,
/// pero queda categorizado aparte para el reporte de utilidad.
class RegistrarMermaScreen extends ConsumerStatefulWidget {
  final Producto producto;
  const RegistrarMermaScreen({super.key, required this.producto});

  @override
  ConsumerState<RegistrarMermaScreen> createState() => _RegistrarMermaScreenState();
}

class _RegistrarMermaScreenState extends ConsumerState<RegistrarMermaScreen> {
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
      await ref.read(stockRepositoryProvider).registrarMerma(
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
      appBar: AppBar(title: Text('Merma: ${widget.producto.nombre}')),
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
                    labelText: 'Cantidad perdida/descartada', border: OutlineInputBorder()),
                validator: (v) => Validators.numeroPositivo(v, campo: 'La cantidad'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Motivo (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
                child: _guardando
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Registrar merma'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
