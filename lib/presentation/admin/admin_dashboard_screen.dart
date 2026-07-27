import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'productos/screens/productos_screen.dart';
import 'stock/screens/stock_screen.dart';
import 'estadisticas/screens/estadisticas_screen.dart';
import 'usuarios/screens/usuarios_screen.dart';
import 'historial/screens/historial_screen.dart';
import 'clientes/screens/clientes_screen.dart';
import '../shared/utils/cerrar_sesion.dart';

/// Menú principal del administrador: acceso a todos los módulos de gestión.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulos = <_ModuloAdmin>[
      _ModuloAdmin('Productos', Icons.eco, const ProductosScreen()),
      _ModuloAdmin('Stock', Icons.inventory_2, const StockScreen()),
      _ModuloAdmin('Estadísticas', Icons.bar_chart, const EstadisticasScreen()),
      _ModuloAdmin('Usuarios', Icons.people, const UsuariosScreen()),
      _ModuloAdmin('Historial', Icons.history, const HistorialScreen()),
      _ModuloAdmin('Clientes', Icons.contacts, const ClientesScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cambiar de usuario',
            onPressed: () => cerrarSesionYVolver(context, ref),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: modulos.map((m) {
          return Card(
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => m.pantalla)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(m.icono, size: 40),
                  const SizedBox(height: 8),
                  Text(m.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }).toList(),
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
