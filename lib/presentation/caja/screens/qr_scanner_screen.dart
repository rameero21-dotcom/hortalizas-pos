import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Escanea el QR de respaldo de una venta (para cuando falla la
/// sincronización automática por red). Devuelve el contenido crudo del
/// QR al hacer pop; quien la abre se encarga de decodificarlo
/// (ver QrService.decodificarPayload vía ReconstruirVentaQrUseCase).
///
/// Pide el permiso de cámara de forma explícita antes de abrir el
/// escáner: en algunas versiones de Android el permiso se puede haber
/// revocado automáticamente (por inactividad de la app) o nunca haberse
/// pedido a tiempo, dejando la cámara con pantalla negra sin avisar.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _yaProcesado = false;
  bool _verificandoPermiso = true;
  bool _permisoConcedido = false;
  bool _permisoDenegadoPermanente = false;

  @override
  void initState() {
    super.initState();
    _verificarPermiso();
  }

  Future<void> _verificarPermiso() async {
    var estado = await Permission.camera.status;
    if (!estado.isGranted) {
      estado = await Permission.camera.request();
    }
    if (!mounted) return;
    setState(() {
      _permisoConcedido = estado.isGranted;
      _permisoDenegadoPermanente = estado.isPermanentlyDenied;
      _verificandoPermiso = false;
    });
  }

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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_verificandoPermiso) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_permisoConcedido) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _permisoDenegadoPermanente
                  ? 'El permiso de cámara está bloqueado. Andá a la configuración del celular > Apps > Hortalizas POS > Permisos, y habilitá la cámara.'
                  : 'Hace falta el permiso de cámara para escanear el QR.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_permisoDenegadoPermanente)
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Abrir configuración'),
              )
            else
              ElevatedButton(
                onPressed: _verificarPermiso,
                child: const Text('Dar permiso'),
              ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        MobileScanner(
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            return Container(
              color: Colors.black,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'No se pudo iniciar la cámara.\n\n'
                      'Código: ${error.errorCode}\n'
                      'Detalle: ${error.errorDetails?.message ?? "(sin detalle)"}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
    );
  }
}
