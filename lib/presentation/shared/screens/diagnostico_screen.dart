import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/gradient_app_bar.dart';
import '../../../core/services/log_service.dart';

/// Muestra el registro de diagnóstico (ver LogService) para mandarlo por
/// WhatsApp o mail cuando algo anduvo mal y no hubo ningún mensaje de
/// error en pantalla para sacarle una foto — "Copiar" lo pone en el
/// portapapeles, listo para pegar en el chat.
///
/// Se puede llegar acá desde el menú de Admin, y también desde la
/// pantalla de login (por si la app nunca llega a dejar entrar).
class DiagnosticoScreen extends StatefulWidget {
  const DiagnosticoScreen({super.key});

  @override
  State<DiagnosticoScreen> createState() => _DiagnosticoScreenState();
}

class _DiagnosticoScreenState extends State<DiagnosticoScreen> {
  late String _contenido;

  @override
  void initState() {
    super.initState();
    _contenido = LogService.leerContenido();
  }

  void _copiar() {
    Clipboard.setData(ClipboardData(text: _contenido));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro copiado al portapapeles')),
    );
  }

  void _borrar() {
    LogService.borrar();
    setState(() => _contenido = LogService.leerContenido());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro borrado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ruta = LogService.ruta();
    return Scaffold(
      appBar: GradientAppBar(
        title: const Text('Diagnóstico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => setState(() => _contenido = LogService.leerContenido()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Si la app se cierra o se traba sin avisar nada, acá queda un registro de hasta dónde llegó '
              'a arrancar. Copialo y mandalo para que se pueda revisar qué pasó.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (ruta != null) ...[
              const SizedBox(height: 8),
              Text(
                'Archivo: $ruta',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _contenido.isEmpty ? 'Todavía no hay nada registrado.' : _contenido,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _contenido.isEmpty ? null : _copiar,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _contenido.isEmpty ? null : _borrar,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Borrar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
