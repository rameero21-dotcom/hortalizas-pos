import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import 'venta_detalle_screen.dart';
import 'qr_scanner_screen.dart';
import 'qr_texto_screen.dart';
import 'arqueo_caja_screen.dart';

bool get _tieneCamaraDeQr => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

final ventasPendientesStreamProvider = StreamProvider((ref) {
  return ref.watch(ventaRemoteDsProvider).observarPendientes();
});

class CajaHomeScreen extends ConsumerWidget {
  const CajaHomeScreen({super.key});

  Future<void> _procesarQr(BuildContext context, WidgetRef ref, String? raw) async {
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventasAsync = ref.watch(ventasPendientesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas pendientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: 'Arqueo de caja',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArqueoCajaScreen()),
            ),
          ),
          IconButton(
            icon: Icon(_tieneCamaraDeQr ? Icons.qr_code_scanner : Icons.qr_code),
            tooltip: _tieneCamaraDeQr
                ? 'Escanear QR (respaldo sin conexión)'
                : 'Pegar código QR (respaldo sin conexión)',
            onPressed: () async {
              final raw = _tieneCamaraDeQr
                  ? await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                    )
                  : await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const QrTextoScreen()),
                    );
              if (context.mounted) await _procesarQr(context, ref, raw);
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
              return Dismissible(
                key: ValueKey(venta.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar venta'),
                          content: Text('¿Eliminar la venta #${venta.numero}? Esta acción no se puede deshacer.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (_) async {
                  await ref.read(ventaRepositoryProvider).eliminarVenta(venta.id);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(
                      venta.nombreCliente != null && venta.nombreCliente!.isNotEmpty
                          ? 'Venta #${venta.numero} · ${venta.nombreCliente}'
                          : 'Venta #${venta.numero}',
                    ),
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