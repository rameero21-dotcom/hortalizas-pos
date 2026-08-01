import 'dart:io';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../core/services/impresora_ticket_service.dart';
import '../../../core/services/impresora_bluetooth_service.dart';
import '../../../core/services/ticket_print_orchestrator.dart';

/// Pantalla para elegir la impresora térmica de tickets. En Windows
/// (cable USB) muestra las impresoras ya instaladas en el sistema; en
/// Android/tablet (Bluetooth) muestra los dispositivos ya emparejados.
/// En cualquier caso, permite mandar un ticket de prueba antes de
/// usarla en serio para las ventas.
class ConfiguracionImpresoraScreen extends StatefulWidget {
  const ConfiguracionImpresoraScreen({super.key});

  @override
  State<ConfiguracionImpresoraScreen> createState() => _ConfiguracionImpresoraScreenState();
}

class _ConfiguracionImpresoraScreenState extends State<ConfiguracionImpresoraScreen> {
  // ---- Windows (USB) ----
  List<String> _impresorasWindows = [];
  String? _impresoraSeleccionada;

  // ---- Android (Bluetooth) ----
  List<BluetoothInfo> _dispositivosBt = [];
  String? _macSeleccionada;

  bool _cargando = true;
  String? _resultadoPrueba;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (Platform.isWindows) {
      final guardada = await ConfigImpresora.obtenerNombreGuardado();
      final lista = ImpresoraTicketService.listarImpresoras();
      setState(() {
        _impresorasWindows = lista;
        _impresoraSeleccionada = guardada != null && lista.contains(guardada) ? guardada : null;
        _cargando = false;
      });
    } else if (Platform.isAndroid) {
      final guardada = await ConfigImpresora.obtenerMacBluetoothGuardada();
      final lista = await ImpresoraBluetoothService.dispositivosEmparejados();
      setState(() {
        _dispositivosBt = lista;
        _macSeleccionada =
            guardada != null && lista.any((d) => d.macAdress == guardada) ? guardada : null;
        _cargando = false;
      });
    } else {
      setState(() => _cargando = false);
    }
  }

  Future<void> _imprimirPruebaWindows() async {
    if (_impresoraSeleccionada == null) return;
    setState(() => _resultadoPrueba = null);
    try {
      final bytes = <int>[
        ...'C&S Hortalizas\n'.codeUnits,
        ...'Prueba de impresora\n'.codeUnits,
        ...'Si ves esto, anda bien!\n\n\n\n'.codeUnits,
      ];
      final ok = ImpresoraTicketService.imprimirRaw(_impresoraSeleccionada!, bytes);
      setState(() => _resultadoPrueba = ok ? 'ok' : 'error');
    } catch (e) {
      setState(() => _resultadoPrueba = 'error: $e');
    }
  }

  Future<void> _imprimirPruebaBluetooth() async {
    if (_macSeleccionada == null) return;
    setState(() => _resultadoPrueba = null);
    try {
      final yaConectado = await ImpresoraBluetoothService.yaConectado();
      if (!yaConectado) {
        final conectado = await ImpresoraBluetoothService.conectar(_macSeleccionada!);
        if (!conectado) {
          setState(() => _resultadoPrueba = 'error: no se pudo conectar por Bluetooth');
          return;
        }
      }
      final bytes = <int>[
        ...'C&S Hortalizas\n'.codeUnits,
        ...'Prueba de impresora\n'.codeUnits,
        ...'Si ves esto, anda bien!\n\n\n\n'.codeUnits,
      ];
      final ok = await ImpresoraBluetoothService.imprimir(bytes);
      setState(() => _resultadoPrueba = ok ? 'ok' : 'error');
    } catch (e) {
      setState(() => _resultadoPrueba = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impresora de tickets'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Platform.isWindows
                  ? _buildWindows()
                  : Platform.isAndroid
                      ? _buildAndroid()
                      : const Text('Esta plataforma todavía no tiene impresión de tickets soportada.'),
            ),
    );
  }

  Widget _buildWindows() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegí cuál de las impresoras ya instaladas en esta PC es la '
          'térmica de tickets (conectada por cable USB). Tiene que estar '
          'agregada primero en "Impresoras y escáneres" de Windows.',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 16),
        if (_impresorasWindows.isEmpty)
          const Text('No se encontró ninguna impresora instalada en Windows.')
        else
          DropdownButtonFormField<String>(
            initialValue: _impresoraSeleccionada,
            decoration: const InputDecoration(labelText: 'Impresora', border: OutlineInputBorder()),
            items: _impresorasWindows.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (n) => setState(() => _impresoraSeleccionada = n),
          ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _impresoraSeleccionada == null
              ? null
              : () async {
                  await ConfigImpresora.guardarNombre(_impresoraSeleccionada!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Impresora guardada')));
                  }
                },
          icon: const Icon(Icons.save),
          label: const Text('Guardar como impresora de tickets'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _impresoraSeleccionada == null ? null : _imprimirPruebaWindows,
          icon: const Icon(Icons.print),
          label: const Text('Imprimir prueba'),
        ),
        _mensajeResultado(),
      ],
    );
  }

  Widget _buildAndroid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegí la impresora Bluetooth (tiene que estar emparejada '
          'primero desde la configuración de Bluetooth de Android, como '
          'cualquier otro dispositivo).',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 16),
        if (_dispositivosBt.isEmpty)
          const Text('No hay dispositivos Bluetooth emparejados. Emparejá la impresora primero.')
        else
          DropdownButtonFormField<String>(
            initialValue: _macSeleccionada,
            decoration:
                const InputDecoration(labelText: 'Impresora Bluetooth', border: OutlineInputBorder()),
            items: _dispositivosBt
                .map((d) => DropdownMenuItem(value: d.macAdress, child: Text(d.name)))
                .toList(),
            onChanged: (mac) => setState(() => _macSeleccionada = mac),
          ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _macSeleccionada == null
              ? null
              : () async {
                  await ConfigImpresora.guardarMacBluetooth(_macSeleccionada!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Impresora guardada')));
                  }
                },
          icon: const Icon(Icons.save),
          label: const Text('Guardar como impresora de tickets'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _macSeleccionada == null ? null : _imprimirPruebaBluetooth,
          icon: const Icon(Icons.print),
          label: const Text('Imprimir prueba'),
        ),
        _mensajeResultado(),
      ],
    );
  }

  Widget _mensajeResultado() {
    if (_resultadoPrueba == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _resultadoPrueba == 'ok'
            ? '✅ Se mandó a imprimir. Fijate si salió algo en la impresora.'
            : '❌ No se pudo mandar a imprimir: $_resultadoPrueba',
        style: TextStyle(color: _resultadoPrueba == 'ok' ? Colors.green : Colors.red),
      ),
    );
  }
}
