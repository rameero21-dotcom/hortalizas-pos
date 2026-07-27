import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../auth/screens/login_screen.dart';

/// Cierra la sesión actual y vuelve a la pantalla de login, limpiando
/// toda la pila de navegación (para que no se pueda "volver" con el
/// botón atrás a la pantalla del usuario anterior).
Future<void> cerrarSesionYVolver(BuildContext context, WidgetRef ref) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cambiar de usuario'),
      content: const Text('¿Cerrar esta sesión y volver a la pantalla de inicio de sesión?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
      ],
    ),
  );
  if (confirmar != true) return;

  await ref.read(authServiceProvider).logout();
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
