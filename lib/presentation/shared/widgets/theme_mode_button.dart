import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_mode_provider.dart';

/// Botón para alternar claro/oscuro, disponible en las pantallas
/// principales de cada rol (admin y caja).
class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esOscuro = ref.watch(themeModeProvider) == ThemeMode.dark;
    return IconButton(
      icon: Icon(esOscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      tooltip: esOscuro ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
      onPressed: () => ref.read(themeModeProvider.notifier).alternar(),
    );
  }
}
