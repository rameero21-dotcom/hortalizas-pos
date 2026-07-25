import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import 'venta_detalle_screen.dart';
import 'qr_scanner_screen.dart';

/// Stream en tiempo real de ventas pendientes directo desde Firestore.
/// Esto es lo que hace que, apenas el vendedor toca "Finalizar venta"
/// en otro celular, esta pantalla la muestre sola (sin tocar nada).
final ventasPendientesStreamProvider = StreamProvider((ref) {
  return ref.watch(ventaRemoteDsProvider).observarPendientes();
});

/// Pantalla principal de caja: lista de ventas pendientes recibidas
/// automáticamente por Firebase, con opción de escanear QR como
/// respaldo si falla la red (Fase 3).
class CajaHomeScreen extends ConsumerWidget {
  const CajaHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventasAsync = ref.watch(ventasPendientesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas pendientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear QR (respaldo sin conexión)',
            onPressed: () async {
              final raw = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
              if (raw == null || !context.mounted) return;
              try {
                final venta = await ref.read(reconstruirVentaQrUseCaseProvider).call(raw);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VentaDetalleScreen(ventaDesdeQr: venta)),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('QR inválido o dañado: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ventasAsync.when(
        data: (ventas) {
          if (ventas.isEmpty) {
            return const Center(child: Text('No hay ventas pendientes'));
          }
          return ListView.builder(
            itemCount: ventas.length,
            itemBuilder: (context, index) {
              final venta = ventas[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('Venta #${venta.numero}'),
                  subtitle: Text(
                      '${venta.detalle.length} producto(s) · ${Formatters.formatearHora(venta.fecha)}'),
                  trailing: Text(
                    Formatters.formatearMoneda(venta.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => VentaDetalleScreen(ventaId: venta.id)),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudo conectar con Firebase.\n\n'
              'Revisá que:\n'
              '• Ya corriste `flutterfire configure` (ver README)\n'
              '• El dispositivo tiene internet\n'
              '• Las reglas de Firestore permiten leer "ventas"\n\n'
              'Detalle técnico: $err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
