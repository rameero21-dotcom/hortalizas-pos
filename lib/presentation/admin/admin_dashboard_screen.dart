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
import '../shared/utils/cerrar_sesion.dart';
import '../shared/widgets/gradient_app_bar.dart';
import '../shared/widgets/indicador_sincronizacion.dart';

/// Menú principal del administrador: acceso a todos los módulos de gestión.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulos = <_ModuloAdmin>[
      _ModuloAdmin('Productos', Icons.eco_outlined, const ProductosScreen()),
      _ModuloAdmin('Stock', Icons.balance_outlined, const StockScreen()),
      _ModuloAdmin('Estadísticas', Icons.insights_outlined, const EstadisticasScreen()),
      _ModuloAdmin('Usuarios', Icons.people_alt_outlined, const UsuariosScreen()),
      _ModuloAdmin('Historial', Icons.history_outlined, const HistorialScreen()),
      _ModuloAdmin('Clientes', Icons.contacts_outlined, const ClientesScreen()),
      _ModuloAdmin('Proveedores', Icons.local_shipping_outlined, const ProveedoresScreen()),
      _ModuloAdmin('Facturación', Icons.request_quote_outlined, const FacturacionScreen()),
      _ModuloAdmin('Impresora', Icons.print_outlined, const ConfiguracionImpresoraScreen()),
    ];

    return Scaffold(
      appBar: GradientAppBar(
        title: const Text('Panel de administración'),
        actions: [
          const IndicadorSincronizacion(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cambiar de usuario',
            onPressed: () => cerrarSesionYVolver(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ACCESOS', style: AppTheme.eyebrowStyle(context)),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < modulos.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _FilaModulo(modulo: modulos[i])
                      // Entrada escalonada: cada fila aparece un poco después
                      // que la anterior, en vez de que las 9 salten de golpe.
                      .animate()
                      .fadeIn(delay: (i * 25).ms, duration: 220.ms, curve: Curves.easeOut),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaModulo extends StatelessWidget {
  final _ModuloAdmin modulo;
  const _FilaModulo({required this.modulo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => modulo.pantalla)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(modulo.icono, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(child: Text(modulo.titulo, style: Theme.of(context).textTheme.bodyLarge)),
            Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ModuloAdmin {
  final String titulo;
  final IconData icono;
  final Widget pantalla;
  _ModuloAdmin(this.titulo, this.icono, this.pantalla);
}
