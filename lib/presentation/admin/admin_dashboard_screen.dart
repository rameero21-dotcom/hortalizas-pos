import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'productos/screens/productos_screen.dart';
import 'stock/screens/stock_screen.dart';
import 'estadisticas/screens/estadisticas_screen.dart';
import 'usuarios/screens/usuarios_screen.dart';
import 'historial/screens/historial_screen.dart';
import 'clientes/screens/clientes_screen.dart';
import '../shared/utils/cerrar_sesion.dart';
import '../shared/widgets/indicador_sincronizacion.dart';

/// Menú principal del administrador: acceso a todos los módulos de gestión.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modulos = <_ModuloAdmin>[
      _ModuloAdmin('Productos', Icons.eco_rounded, const ProductosScreen(), colorScheme.secondary),
      _ModuloAdmin('Stock', Icons.balance_rounded, const StockScreen(), colorScheme.primary),
      _ModuloAdmin('Estadísticas', Icons.insights_rounded, const EstadisticasScreen(), colorScheme.secondary),
      _ModuloAdmin('Usuarios', Icons.people_alt_rounded, const UsuariosScreen(), colorScheme.primary),
      _ModuloAdmin('Historial', Icons.history_rounded, const HistorialScreen(), colorScheme.secondary),
      _ModuloAdmin('Clientes', Icons.contacts_rounded, const ClientesScreen(), colorScheme.primary),
    ];

    return Scaffold(
      appBar: AppBar(
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
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          // En vez de una cantidad fija de columnas (que en una ventana
          // ancha de Windows deja cada ícono gigante), esto arma tantas
          // columnas como entren manteniendo cada tarjeta en un tamaño
          // razonable — así entran todos los accesos sin desplazarse.
          maxCrossAxisExtent: 160,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: modulos.length,
        itemBuilder: (context, i) {
          final m = modulos[i];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => m.pantalla)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: m.color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(m.icono, size: 26, color: m.color),
                  ),
                  const SizedBox(height: 10),
                  Text(m.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModuloAdmin {
  final String titulo;
  final IconData icono;
  final Widget pantalla;
  final Color color;
  _ModuloAdmin(this.titulo, this.icono, this.pantalla, this.color);
}
