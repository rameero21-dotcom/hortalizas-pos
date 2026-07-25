import 'package:flutter/material.dart';

/// Tema de la aplicación: Material Design 3, modo claro y oscuro.
/// Botones grandes e interfaz minimalista pensada para uso intensivo todo el día.
class AppTheme {
  static const Color primaryColor = Color(0xFF2E7D32); // Verde (hortalizas)
  static const Color secondaryColor = Color(0xFFFFA000); // Ámbar acentos

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        textTheme: _textTheme,
        elevatedButtonTheme: _bigButtonTheme,
        visualDensity: VisualDensity.comfortable,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
