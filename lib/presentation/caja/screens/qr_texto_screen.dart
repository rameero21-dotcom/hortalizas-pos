import 'package:flutter/material.dart';

class QrTextoScreen extends StatefulWidget {
  const QrTextoScreen({super.key});

  @override
  State<QrTextoScreen> createState() => _QrTextoScreenState();
}

class _QrTextoScreenState extends State<QrTextoScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar código QR de venta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En la PC no se puede leer el QR con cámara. Podés leerlo '
              'con cualquier app lectora de QR desde un celular y pegar '
              'acá el texto que contiene.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Contenido del QR',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.trim().isEmpty) return;
                Navigator.pop(context, _controller.text.trim());
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}