import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/impresora_ticket_service.dart';

const _kClaveImpresora = 'nombre_impresora_ticket';

/// Guarda/lee qué impresora de Windows se usa para los tickets.
class ConfigImpresora {
  static Future<String?> obtenerNombreGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kClaveImpresora);
  }

  static Future<void> guardarNombre(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClaveImpresora, nombre);
  }
}

/// Pantalla para elegir la impresora térmica (de las que ya están
/// instaladas en Windows) y mandar un ticket de prueba, antes de usarla
/// en serio para las ventas.
class ConfiguracionImpresoraScreen extends StatefulWidget {
  const ConfiguracionImpresoraScreen({super.key});

  @override
  State<ConfiguracionImpresoraScreen> createState() => _ConfiguracionImpresoraScreenState();
}

class _ConfiguracionImpresoraScreenState extends State<ConfiguracionImpresoraScreen> {
  List<String> _impresoras = [];
  String? _seleccionada;
  bool _cargando = true;
  String? _resultadoPrueba;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final guardada = await ConfigImpresora.obtenerNombreGuardado();
    final lista = ImpresoraTicketService.listarImpresoras();
    setState(() {
      _impresoras = lista;
      _seleccionada = guardada != null && lista.contains(guardada) ? guardada : null;
      _cargando = false;
    });
  }

  Future<void> _imprimirPrueba() async {
    if (_seleccionada == null) return;
    setState(() => _resultadoPrueba = null);
    try {
      // Ticket de prueba simple, sin depender de una venta real.
      final bytes = <int>[
        ...'C&S Hortalizas\n'.codeUnits,
        ...'Prueba de impresora\n'.codeUnits,
        ...'Si ves esto, anda bien!\n\n\n\n'.codeUnits,
      ];
      final ok = ImpresoraTicketService.imprimirRaw(_seleccionada!, bytes);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Elegí cuál de las impresoras ya instaladas en esta PC es la '
                    'térmica de tickets. Tiene que estar agregada primero en '
                    '"Impresoras y escáneres" de Windows.',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 16),
                  if (_impresoras.isEmpty)
                    const Text('No se encontró ninguna impresora instalada en Windows.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _seleccionada,
                      decoration: const InputDecoration(labelText: 'Impresora', border: OutlineInputBorder()),
                      items: _impresoras.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                      onChanged: (n) => setState(() => _seleccionada = n),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _seleccionada == null
                        ? null
                        : () async {
                            await ConfigImpresora.guardarNombre(_seleccionada!);
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
                    onPressed: _seleccionada == null ? null : _imprimirPrueba,
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir prueba'),
                  ),
                  if (_resultadoPrueba != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _resultadoPrueba == 'ok'
                          ? '✅ Se mandó a imprimir. Fijate si salió algo en la impresora.'
                          : '❌ No se pudo mandar a imprimir: $_resultadoPrueba',
                      style: TextStyle(color: _resultadoPrueba == 'ok' ? Colors.green : Colors.red),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
