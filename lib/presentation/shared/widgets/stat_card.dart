import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Tarjeta para métricas tipo KPI (ventas del día, facturación,
/// utilidad, etc.). Antes cada pantalla de estadísticas/resumen
/// armaba la suya con estilos sueltos (grises hardcodeados que no se
/// adaptaban a tema claro/oscuro); esta es la única versión.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool destacado;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.destacado = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colorValor = valueColor ?? (destacado ? colorScheme.secondary : null);

    return Card(
      color: destacado ? colorScheme.secondary.withOpacity(0.12) : null,
      shape: destacado
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.secondary),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: colorScheme.secondary),
              const SizedBox(height: 8),
            ],
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(color: colorValor),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }
}
