import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../domain/entities/cliente.dart';

String _labelCondicion(CondicionFiscal c) => switch (c) {
      CondicionFiscal.monotributista => 'Monotributista',
      CondicionFiscal.responsableInscripto => 'Responsable Inscripto',
    };

/// Formulario de cliente. Carga progresiva: primero el nombre, y recién
/// cuando eso está cargado aparece el campo de CUIT/DNI, y recién
/// cuando ese está cargado aparece la condición fiscal — para que el
/// flujo se sienta guiado en vez de tirar todos los campos juntos.
/// Estos dos últimos datos son los que necesita el contador para poder
/// facturar (ver el acceso de Facturación en el panel de admin).
class ClienteFormScreen extends ConsumerStatefulWidget {
  final Cliente? cliente;
  const ClienteFormScreen({super.key, this.cliente});

  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends ConsumerState<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _cuitDniCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _saldoCtrl;
  CondicionFiscal? _condicionFiscal;
  bool _guardando = false;
  // true = el cliente debe (se guarda en negativo); false = saldo a
  // favor del cliente (positivo). Así el que carga el monto no tiene
  // que acordarse de poner el signo menos a mano.
  bool _clienteDebe = true;

  bool get _esEdicion => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.cliente?.nombre ?? '')..addListener(_onCambio);
    _cuitDniCtrl = TextEditingController(text: widget.cliente?.cuitODni ?? '')..addListener(_onCambio);
    _telefonoCtrl = TextEditingController(text: widget.cliente?.telefono ?? '');
    _direccionCtrl = TextEditingController(text: widget.cliente?.direccion ?? '');
    _saldoCtrl = TextEditingController(
        text: widget.cliente != null ? widget.cliente!.saldoCuentaCorriente.abs().toStringAsFixed(0) : '0');
    _clienteDebe = widget.cliente == null || widget.cliente!.saldoCuentaCorriente <= 0;
    _condicionFiscal = widget.cliente?.condicionFiscal;
  }

  void _onCambio() => setState(() {}); // solo para reevaluar qué campos mostrar

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cuitDniCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _saldoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_esEdicion && _condicionFiscal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí la condición fiscal del cliente')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final montoSaldo = double.tryParse(_saldoCtrl.text.replaceAll(',', '.'))?.abs() ?? 0;
      final cliente = Cliente(
        id: widget.cliente?.id ?? const Uuid().v4(),
        nombre: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        saldoCuentaCorriente: _clienteDebe ? -montoSaldo : montoSaldo,
        cuitODni: _cuitDniCtrl.text.trim(),
        condicionFiscal: _condicionFiscal,
      );
      final usecase = ref.read(gestionarClientesUseCaseProvider);
      if (_esEdicion) {
        await usecase.actualizar(cliente);
      } else {
        await usecase.crear(cliente);
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
    final nombreCargado = _nombreCtrl.text.trim().isNotEmpty;
    final cuitDniCargado = _cuitDniCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar cliente' : 'Nuevo cliente')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                autofocus: !_esEdicion,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                validator: (v) => Validators.requerido(v, campo: 'El nombre'),
              ),
              if (nombreCargado) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cuitDniCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CUIT o DNI',
                    helperText: 'Necesario para que el contador pueda facturarle',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _esEdicion ? null : Validators.requerido(v, campo: 'El CUIT o DNI'),
                ),
              ],
              if (nombreCargado && cuitDniCargado) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<CondicionFiscal>(
                  initialValue: _condicionFiscal,
                  decoration:
                      const InputDecoration(labelText: 'Condición fiscal', border: OutlineInputBorder()),
                  items: CondicionFiscal.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(_labelCondicion(c))))
                      .toList(),
                  onChanged: (c) => setState(() => _condicionFiscal = c),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Cuenta corriente al día de hoy', style: TextStyle(color: Colors.grey.shade400)),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('El cliente debe')),
                  ButtonSegment(value: false, label: Text('Saldo a favor')),
                ],
                selected: {_clienteDebe},
                onSelectionChanged: (s) => setState(() => _clienteDebe = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _saldoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  helperText: 'Dejalo en 0 si el cliente arranca sin deuda ni saldo a favor',
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
                    : Text(_esEdicion ? 'Guardar cambios' : 'Crear cliente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
