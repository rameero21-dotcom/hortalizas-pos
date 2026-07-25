import 'package:flutter/material.dart';

/// Formulario de creación/edición de usuario (nombre, email, rol, activo).
class UsuarioFormScreen extends StatelessWidget {
  final String? usuarioId;
  const UsuarioFormScreen({super.key, this.usuarioId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(usuarioId == null ? 'Nuevo usuario' : 'Editar usuario')),
      body: const Center(child: Text('TODO Fase 4: formulario de usuario + selección de rol')),
    );
  }
}
