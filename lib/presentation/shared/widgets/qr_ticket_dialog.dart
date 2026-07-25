import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Diálogo que muestra el QR de respaldo de una venta recién finalizada
/// (según especificación: el QR es solo respaldo, la sincronización
/// automática es el método principal).
class QrTicketDialog extends StatelessWidget {
  final String payload;
  final int numeroVenta;

  const QrTicketDialog({super.key, required this.payload, required this.numeroVenta});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Venta #$numeroVenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(data: payload, size: 220),
          const SizedBox(height: 12),
          const Text('Este QR es solo un respaldo. La venta ya fue enviada a caja.'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}
