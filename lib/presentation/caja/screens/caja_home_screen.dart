import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../shared/widgets/gradient_app_bar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import 'venta_detalle_screen.dart';
import 'qr_scanner_screen.dart';
import 'qr_texto_screen.dart';
import 'arqueo_caja_screen.dart';
import '../../admin/historial/screens/historial_screen.dart';
import '../../admin/clientes/screens/clientes_screen.dart';
import '../../shared/providers/theme_mode_provider.dart';
import '../../shared/utils/cerrar_sesion.dart';
import '../../shared/widgets/indicador_sincronizacion.dart';
import '../../shared/widgets/loading_widget.dart';

bool get _tieneCamaraDeQr => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Se reintenta un par de veces si falla al principio: justo al abrir la
/// app (sobre todo con sesión guardada, entrando directo sin login), a
/// veces el token de autenticación de Firebase todavía no terminó de
/// prepararse en el mismo instante en que se intenta leer "ventas",
/// dando un error de permisos transitorio que se resuelve solo un
/// instante después. Sin este reintento, el usuario veía el error y
/// tenía que actualizar a mano aunque en realidad no había ningún
/// problema real de conexión ni de permisos.
final ventasPendientesStreamProvider = StreamProvider((ref) async* {
  final datasource = ref.watch(ventaRemoteDsProvider);
  var intentos = 0;
  while (true) {
    try {
      yield* datasource.observarPendientes();
      return;
    } catch (e) {
      intentos++;
      if (intentos >= 4) rethrow; // ya reintentó varias veces: mostrar el error de verdad
      await Future.delayed(Duration(milliseconds: 600 * intentos));
    }
  }
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

  Future<void> _actualizar(WidgetRef ref) async {
    // Fuerza al stream a reconectar, para reflejar ventas nuevas del
    // vendedor sin esperar (o como respaldo si la conexión se colgó).
    ref.invalidate(ventasPendientesStreamProvider);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventasAsync = ref.watch(ventasPendientesStreamProvider);

    return Scaffold(
      appBar: GradientAppBar(
        title: const Text('Ventas pendientes'),
        actions: [
          const IndicadorSincronizacion(),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (valor) {
              switch (valor) {
                case 'actualizar':
                  _actualizar(ref);
                  break;
                case 'tema':
                  ref.read(themeModeProvider.notifier).alternar();
                  break;
                case 'salir':
                  cerrarSesionYVolver(context, ref);
                  break;
              }
            },
            itemBuilder: (context) {
              final esOscuro = ref.read(themeModeProvider) == ThemeMode.dark;
              return [
                const PopupMenuItem(
                  value: 'actualizar',
                  child: ListTile(leading: Icon(Icons.refresh), title: Text('Actualizar')),
                ),
                PopupMenuItem(
                  value: 'tema',
                  child: ListTile(
                    leading: Icon(esOscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                    title: Text(esOscuro ? 'Modo claro' : 'Modo oscuro'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'salir',
                  child: ListTile(leading: Icon(Icons.logout), title: Text('Cambiar de usuario')),
                ),
              ];
            },
          ),
        ],
      ),
      // El escaneo de QR (respaldo sin conexión) queda como botón flotante:
      // es la acción que más se usa durante el día, a diferencia de
      // Historial/Clientes/Arqueo que ahora viven en la barra de abajo.
      floatingActionButton: FloatingActionButton(
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
        child: Icon(_tieneCamaraDeQr ? Icons.qr_code_scanner : Icons.qr_code),
      ),
      // Siempre arranca en "Ventas" (índice 0, esta misma pantalla): las
      // otras tres navegan empujando su pantalla de siempre, así que no
      // hace falta mantener un índice seleccionado real.
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (indice) {
          switch (indice) {
            case 1:
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistorialScreen()));
              break;
            case 2:
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientesScreen()));
              break;
            case 3:
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ArqueoCajaScreen()));
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Ventas',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Arqueo',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _actualizar(ref),
        child: ventasAsync.when(
          data: (ventas) {
            if (ventas.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(child: Text('No hay ventas pendientes')),
                  ),
                ],
              );
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
                            content: Text(
                                '¿Eliminar la venta #${venta.numero}? Esta acción no se puede deshacer.'),
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
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.receipt_long_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(
                        venta.nombreCliente != null && venta.nombreCliente!.isNotEmpty
                            ? 'Venta #${venta.numero} · ${venta.nombreCliente}'
                            : 'Venta #${venta.numero}',
                      ),
                      subtitle: Text(
                          '${venta.detalle.length} producto(s) · ${Formatters.formatearHora(venta.fecha)}'
                          '${venta.vendedorNombre != null ? ' · Vend: ${venta.vendedorNombre}' : ''}'),
                      trailing: Text(
                        Formatters.formatearMoneda(venta.total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
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
          loading: () => const LoadingWidget(),
          error: (err, __) => ListView(
            children: [
              Padding(
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
            ],
          ),
        ),
      ),
    );
  }
}
