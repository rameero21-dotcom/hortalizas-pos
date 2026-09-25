import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Estado vacío consistente para listas sin datos: ícono + mensaje,
/// con acción opcional (ej. un botón "Agregar"). Reemplaza los textos
/// sueltos ("No hay productos todavía...") que cada pantalla repetía
/// con su propio estilo.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorMuted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorMuted)
                .animate()
                .fadeIn(duration: 300.ms)
                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 300.ms, curve: Curves.easeOut),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: colorMuted),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
