import 'package:flutter/material.dart';

/// Encabezado de la app. Antes tenía un degradé de marca (azul →
/// azul profundo); el rediseño premium lo dejó plano, heredando el
/// color de fondo (marfil en claro) directo del tema — las pantallas
/// se separan con líneas finas, no con bloques de color. Queda como
/// reemplazo directo de AppBar (misma API: title/actions/bottom) así
/// que ninguna de las ~30 pantallas que ya lo usan necesitó cambios.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const GradientAppBar({super.key, this.title, this.actions, this.bottom});

  @override
  Widget build(BuildContext context) {
    return AppBar(title: title, actions: actions, bottom: bottom);
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
