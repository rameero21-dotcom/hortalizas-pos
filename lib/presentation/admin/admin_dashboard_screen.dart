import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'productos/screens/productos_screen.dart';
import 'stock/screens/stock_screen.dart';
import 'estadisticas/screens/estadisticas_screen.dart';
import 'usuarios/screens/usuarios_screen.dart';
import 'historial/screens/historial_screen.dart';
import 'clientes/screens/clientes_screen.dart';
import 'proveedores/screens/proveedores_screen.dart';
import 'facturacion/screens/facturacion_screen.dart';
import '../caja/screens/configuracion_impresora_screen.dart';
import '../shared/providers/theme_mode_provider.dart';
import '../shared/utils/cerrar_sesion.dart';
import '../shared/widgets/gradient_app_bar.dart';
import '../shared/widgets/indicador_sincronizacion.dart';

/// Menú principal del administrador: acceso a todos los módulos de gestión,
/// agrupados por tema (antes era una sola lista vertical de 9 filas, más
/// lenta de escanear de un vistazo que una grilla agrupada).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secciones = <_SeccionModulos>[
      _SeccionModulos('VENTAS', [
        _ModuloAdmin('Historial', Icons.history_outlined, const HistorialScreen()),
        _ModuloAdmin('Estadísticas', Icons.insights_outlined, const EstadisticasScreen()),
        _ModuloAdmin('Facturación', Icons.request_quote_outlined, const FacturacionScreen()),
      ]),
      _SeccionModulos('CATÁLOGO', [
        _ModuloAdmin('Productos', Icons.eco_outlined, const ProductosScreen()),
        _ModuloAdmin('Stock', Icons.balance_outlined, const StockScreen()),
      ]),
      _SeccionModulos('PERSONAS', [
        _ModuloAdmin('Clientes', Icons.contacts_outlined, const ClientesScreen()),
        _ModuloAdmin('Proveedores', Icons.local_shipping_outlined, const ProveedoresScreen()),
        _ModuloAdmin('Usuarios', Icons.people_alt_outlined, const UsuariosScreen()),
      ]),
      _SeccionModulos('SISTEMA', [
        _ModuloAdmin('Impresora', Icons.print_outlined, const ConfiguracionImpresoraScreen()),
      ]),
    ];

    var indice = 0;

    return Scaffold(
      appBar: GradientAppBar(
        title: const Text('Panel de administración'),
        actions: [
          const IndicadorSincronizacion(),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (valor) {
              switch (valor) {
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final seccion in secciones) ...[
            Text(seccion.titulo, style: AppTheme.eyebrowStyle(context)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final modulo in seccion.modulos)
                  _TileModulo(modulo: modulo)
                      // Entrada escalonada: cada tile aparece un poco después
                      // que la anterior, en vez de que salten todas de golpe.
                      .animate(delay: ((indice++) * 25).ms)
                      .fadeIn(duration: 220.ms, curve: Curves.easeOut),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _TileModulo extends StatelessWidget {
  final _ModuloAdmin modulo;
  const _TileModulo({required this.modulo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 108,
      height: 100,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => modulo.pantalla)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(modulo.icono, color: colorScheme.primary, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  modulo.titulo,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeccionModulos {
  final String titulo;
  final List<_ModuloAdmin> modulos;
  _SeccionModulos(this.titulo, this.modulos);
}

class _ModuloAdmin {
  final String titulo;
  final IconData icono;
  final Widget pantalla;
  _ModuloAdmin(this.titulo, this.icono, this.pantalla);
}
