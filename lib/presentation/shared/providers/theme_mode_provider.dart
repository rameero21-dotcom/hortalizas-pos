import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/theme_prefs.dart';

/// Arranca en claro (mismo default que antes de tener toggle) y carga
/// la preferencia guardada apenas se crea — async porque
/// SharedPreferences lo es, por eso no se puede leer en el estado
/// inicial directamente.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _cargar();
  }

  Future<void> _cargar() async {
    final oscuro = await ThemePrefs.obtenerModoOscuro();
    state = oscuro ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> alternar() async {
    final nuevoOscuro = state != ThemeMode.dark;
    state = nuevoOscuro ? ThemeMode.dark : ThemeMode.light;
    await ThemePrefs.guardarModoOscuro(nuevoOscuro);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());
