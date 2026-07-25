import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Escanea el QR de respaldo de una venta (para cuando falla la
/// sincronización automática por red). Devuelve el contenido crudo del
/// QR al hacer pop; quien la abre se encarga de decodificarlo
/// (ver QrService.decodificarPayload vía ReconstruirVentaQrUseCase).
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _yaProcesado = false;

  void _onDetect(BarcodeCapture capture) {
    if (_yaProcesado) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null) return;
    _yaProcesado = true;
    Navigator.pop(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR de venta')),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          MobileScanner(onDetect: _onDetect),
          Container(
            width: double.infinity,
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Apuntá al QR que muestra el celular del vendedor',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
