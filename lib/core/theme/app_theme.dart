import 'package:flutter/material.dart';

/// Tema de la aplicación con los colores de marca de C&S Hortalizas:
/// azul (#1226A9, el de "C&S" en el logo) como color principal, y
/// naranja (#FE9015, el de "HORTALIZAS PESADAS") como acento para
/// destacar montos importantes y llamadas a la acción.
class AppTheme {
  static const Color primaryColor = Color(0xFF1226A9); // Azul de marca
  static const Color secondaryColor = Color(0xFFFE9015); // Naranja de marca

  // Fondo oscuro y tarjetas: pensado para uso prolongado en pantalla
  // (menos cansador para la vista, y ahorra batería en pantallas OLED).
  static const Color _fondoOscuro = Color(0xFF0F1115);
  static const Color _superficieOscura = Color(0xFF1B1E24);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ).copyWith(secondary: secondaryColor, tertiary: secondaryColor),
        textTheme: _textTheme,
        elevatedButtonTheme: _bigButtonTheme,
        visualDensity: VisualDensity.comfortable,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _fondoOscuro,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ).copyWith(
          secondary: secondaryColor,
          tertiary: secondaryColor,
          surface: _fondoOscuro,
          surfaceContainerHighest: _superficieOscura,
        ),
        cardTheme: CardThemeData(
          color: _superficieOscura,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _superficieOscura,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: _textTheme,
        elevatedButtonTheme: _bigButtonTheme,
        visualDensity: VisualDensity.comfortable,
      );

  static const TextTheme _textTheme = TextTheme(
    // TODO: ajustar tipografía final (google_fonts) según preferencia visual.
  );

  static final ElevatedButtonThemeData _bigButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 56), // botones grandes
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
