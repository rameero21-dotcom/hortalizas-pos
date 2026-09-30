import 'package:flutter/material.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../domain/entities/proveedor.dart';
import 'proveedor_detalle_screen.dart' show proveedorActualProvider;

/// Formulario de proveedor: nombre, teléfono, y el saldo de cuenta
/// corriente (cuánto le debemos), editable a mano igual que en
/// Clientes.
class ProveedorFormScreen extends ConsumerStatefulWidget {
  final Proveedor? proveedor;
  const ProveedorFormScreen({super.key, this.proveedor});

  @override
  ConsumerState<ProveedorFormScreen> createState() => _ProveedorFormScreenState();
}

class _ProveedorFormScreenState extends ConsumerState<ProveedorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _saldoCtrl;
  bool _guardando = false;
  // true = le debemos al proveedor (se guarda en positivo); false =
  // saldo a favor nuestro (negativo, ej. le pagamos de más). Así el
  // que carga el monto no tiene que acordarse del signo.
  bool _leDebemos = true;

  bool get _esEdicion => widget.proveedor != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.proveedor?.nombre ?? '');
    _telefonoCtrl = TextEditingController(text: widget.proveedor?.telefono ?? '');
    _saldoCtrl = TextEditingController(
        text: widget.proveedor != null ? widget.proveedor!.saldoCuentaCorriente.abs().toStringAsFixed(0) : '0');
    _leDebemos = widget.proveedor == null || widget.proveedor!.saldoCuentaCorriente >= 0;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _saldoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final montoSaldo = Formatters.parsearMonto(_saldoCtrl.text)?.abs() ?? 0;
      final saldoNuevo = _leDebemos ? montoSaldo : -montoSaldo;
      final proveedor = Proveedor(
        id: widget.proveedor?.id ?? const Uuid().v4(),
        nombre: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        activo: widget.proveedor?.activo ?? true,
        saldoCuentaCorriente: saldoNuevo,
      );
      final repo = ref.read(proveedorRepositoryProvider);
      if (_esEdicion) {
        await repo.actualizar(proveedor);
        // Si el admin cambió el saldo a mano, eso se registra como un
        // movimiento (pedido o pago con nota "Ajuste manual"), para que
        // quede en el historial de la pantalla de detalle — igual que
        // el ajuste manual de saldo en Clientes — y para que suba como
        // incremento atómico en vez de pisar cambios hechos desde otro
        // dispositivo.
        // Se usa el saldo más reciente posible como base (no la foto
        // fija con la que se abrió este formulario): ver el mismo
        // comentario en ClienteFormScreen._guardar.
        final saldoBase =
            ref.read(proveedorActualProvider(widget.proveedor!.id)).valueOrNull?.saldoCuentaCorriente ??
                widget.proveedor!.saldoCuentaCorriente;
        final diferencia = saldoNuevo - saldoBase;
        if (diferencia.abs() >= 0.01) {
          final usuarioId = ref.read(currentUserIdProvider);
          if (diferencia > 0) {
            // Le debemos más que antes: se registra como un "pedido"
            // genérico (mismo mecanismo que suma al saldo).
            await repo.registrarPedido(PedidoProveedor(
              id: const Uuid().v4(),
              proveedorId: proveedor.id,
              productoNombre: 'Ajuste manual de saldo',
              cantidad: 1,
              precioUnitario: diferencia,
              fecha: DateTime.now(),
              usuarioId: usuarioId,
            ));
          } else {
            await repo.registrarPago(PagoProveedor(
              id: const Uuid().v4(),
              proveedorId: proveedor.id,
              monto: diferencia.abs(),
              metodoPago: MetodoPagoProveedor.efectivo,
              fecha: DateTime.now(),
              usuarioId: usuarioId,
              nota: 'Ajuste manual de saldo',
            ));
          }
        }
      } else {
        await repo.crear(proveedor);
      }
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
  Widget build(BuildContext context) {
    // Mantiene vivo el stream del proveedor mientras el formulario está
    // abierto, para que al guardar el ajuste de saldo se calcule contra
    // el valor más reciente (ver _guardar).
    if (_esEdicion) ref.watch(proveedorActualProvider(widget.proveedor!.id));

    return Scaffold(
      appBar: GradientAppBar(title: Text(_esEdicion ? 'Editar proveedor' : 'Nuevo proveedor')),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Cuenta corriente al día de hoy', style: TextStyle(color: Colors.grey.shade400)),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Le debemos')),
                  ButtonSegment(value: false, label: Text('A favor nuestro')),
                ],
                selected: {_leDebemos},
                onSelectionChanged: (s) => setState(() => _leDebemos = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _saldoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  helperText: 'Dejalo en 0 si el proveedor arranca sin deuda ni saldo a favor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_esEdicion ? 'Guardar cambios' : 'Crear proveedor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
