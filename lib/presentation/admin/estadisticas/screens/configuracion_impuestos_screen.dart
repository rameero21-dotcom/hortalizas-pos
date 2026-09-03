import 'package:flutter/material.dart';
import '../../../../core/services/configuracion_impuestos.dart';

/// Permite ajustar los porcentajes de IIBB y TSH que se aplican
/// automáticamente sobre cada venta para calcular el reporte de
/// utilidad. Por defecto vienen en 3.5% y 1% (los valores de la
/// planilla de control diario), pero pueden cambiar según la
/// jurisdicción o el rubro.
class ConfiguracionImpuestosScreen extends StatefulWidget {
  const ConfiguracionImpuestosScreen({super.key});

  @override
  State<ConfiguracionImpuestosScreen> createState() => _ConfiguracionImpuestosScreenState();
}

class _ConfiguracionImpuestosScreenState extends State<ConfiguracionImpuestosScreen> {
  final _iibbCtrl = TextEditingController();
  final _tshCtrl = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final iibb = await ConfiguracionImpuestos.obtenerTasaIIBB();
    final tsh = await ConfiguracionImpuestos.obtenerTasaTSH();
    _iibbCtrl.text = (iibb * 100).toStringAsFixed(2);
    _tshCtrl.text = (tsh * 100).toStringAsFixed(2);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final iibb = (double.tryParse(_iibbCtrl.text.replaceAll(',', '.')) ?? 3.5) / 100;
    final tsh = (double.tryParse(_tshCtrl.text.replaceAll(',', '.')) ?? 1.0) / 100;
    final subioIIBB = await ConfiguracionImpuestos.guardarTasaIIBB(iibb);
    final subioTSH = await ConfiguracionImpuestos.guardarTasaTSH(tsh);
    if (mounted) {
      setState(() => _guardando = false);
      final subioOk = subioIIBB && subioTSH;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(subioOk
              ? 'Porcentajes guardados'
              : 'Se guardó en este dispositivo, pero no se pudo subir a la nube (revisá la conexión). '
                  'Los demás dispositivos van a seguir usando el valor anterior hasta que haya señal acá.'),
          duration: subioOk ? const Duration(seconds: 3) : const Duration(seconds: 6),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _iibbCtrl.dispose();
    _tshCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Porcentajes de impuestos')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Se aplican automáticamente sobre cada venta para calcular '
                    'IIBB, TSH y utilidad en Estadísticas. Por defecto: 3.5% y 1% '
                    '(los valores de la planilla de control diario).',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _iibbCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'IIBB (%)',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tshCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'TSH (%)',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ),
    );
  }
}
