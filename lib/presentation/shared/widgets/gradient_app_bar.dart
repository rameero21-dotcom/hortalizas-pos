import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// AppBar de marca: un degradé sutil del azul de C&S Hortalizas hacia
/// un azul más profundo (de arriba-izquierda a abajo-derecha), en vez
/// del azul plano de Material por defecto. Da un poco de profundidad
/// sin perder legibilidad ni chocar con el acento naranja que ya se
/// usa en íconos y tarjetas destacadas.
///
/// Reemplazo directo de AppBar: misma API (title/actions/bottom), así
/// que cualquier pantalla puede cambiar `AppBar(` por
/// `GradientAppBar(` sin tocar nada más.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const GradientAppBar({super.key, this.title, this.actions, this.bottom});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      bottom: bottom,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      // Tiene que ser Container, no un DecoratedBox suelto ni un
      // Positioned: AppBar mete el flexibleSpace dentro de un Semantics
      // antes de llegar al Stack, así que Positioned no puede usarse ahí
      // directamente (revienta con "Incorrect use of ParentDataWidget").
      // Un DecoratedBox sin hijo se queda en tamaño cero; Container sí
      // sabe expandirse para llenar el espacio disponible en ese
      // contexto (internamente usa LimitedBox + ConstrainedBox.expand).
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, Color(0xFF0C1B7A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
