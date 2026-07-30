import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../domain/entities/usuario.dart';

final usuariosListProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(usuarioRepositoryProvider).obtenerTodos();
});

/// Administración de usuarios: administrador, vendedor, cajero,
/// con permisos distintos por rol.
///
/// LIMITACIÓN ACTUAL: crear un usuario de Firebase Auth desde el celular
/// del administrador cerraría su propia sesión (es una limitación del
/// SDK cliente, no de esta app). Por eso, por ahora los usuarios se
/// crean a mano en Firebase Console (ver README, sección 5) y acá solo
/// se listan los que ya iniciaron sesión al menos una vez en este
/// dispositivo. Automatizar la creación queda para cuando se agregue
/// una Cloud Function (Fase 5).
class UsuariosScreen extends ConsumerWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(usuariosListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
            padding: const EdgeInsets.all(12),
            child: Text(
              'Los usuarios se crean por ahora desde Firebase Console '
              '(ver README, sección 5). Acá se listan los que ya '
              'iniciaron sesión en este celular.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          Expanded(
            child: usuariosAsync.when(
              data: (usuarios) {
                if (usuarios.isEmpty) {
                  return const Center(child: Text('Todavía nadie inició sesión en este dispositivo.'));
                }
                return ListView.builder(
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final Usuario u = usuarios[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?'),
                        ),
                        title: Text(u.nombre),
                        subtitle: Text(u.email),
                        trailing: Chip(
                          label: Text(_labelRol(u.rol)),
                          backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.18),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, __) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  String _labelRol(RolUsuario rol) => switch (rol) {
        RolUsuario.administrador => 'Administrador',
        RolUsuario.vendedor => 'Vendedor',
        RolUsuario.cajero => 'Cajero',
      };
}
