import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema de la aplicación con los colores de marca de C&S Hortalizas:
/// azul (#1226A9, el de "C&S" en el logo) como color principal, y
/// naranja (#FE9015, el de "HORTALIZAS PESADAS") como acento para
/// destacar montos importantes y llamadas a la acción.
///
/// `light` y `dark` se arman con la misma función (`_build`) para que
/// nunca vuelvan a desalinearse entre sí: cualquier ajuste de card,
/// appbar, inputs o botones se aplica a los dos modos por igual.
class AppTheme {
  static const Color primaryColor = Color(0xFF1226A9); // Azul de marca
  static const Color secondaryColor = Color(0xFFFE9015); // Naranja de marca

  // Radios de borde unificados: mismo lenguaje visual en toda la app
  // (inputs más chicos que botones, botones más chicos que cards).
  static const double radiusInput = 12;
  static const double radiusButton = 14;
  static const double radiusCard = 16;

  // Fondo y tarjetas en modo claro: gris muy suave detrás de tarjetas
  // blancas, en vez del blanco plano por defecto de Material.
  static const Color _fondoClaro = Color(0xFFF4F5F8);
  static const Color _superficieClara = Colors.white;

  // Fondo oscuro y tarjetas: pensado para uso prolongado en pantalla
  // (menos cansador para la vista, y ahorra batería en pantallas OLED).
  static const Color _fondoOscuro = Color(0xFF0F1115);
  static const Color _superficieOscura = Color(0xFF1B1E24);

  static ThemeData get light => _build(brightness: Brightness.light);

  static ThemeData get dark => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final fondo = isDark ? _fondoOscuro : _fondoClaro;
    final superficie = isDark ? _superficieOscura : _superficieClara;
    final bordeSutil =
        isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.08);
    final textTheme = _buildTextTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: fondo,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      ).copyWith(
        secondary: secondaryColor,
        tertiary: secondaryColor,
        surface: fondo,
        surfaceContainerHighest: superficie,
      ),
      textTheme: textTheme,
      visualDensity: VisualDensity.comfortable,
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: bordeSutil),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficie,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: bordeSutil),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: bordeSutil),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? _superficieOscura : const Color(0xFF1F2430),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusInput),
        ),
      ),
      // Botón principal: grande y a todo el ancho (pensado para CTAs de
      // POS como "Cobrar" o "Confirmar"). Outlined/Text quedan con su
      // ancho natural porque se usan sobre todo como acciones chicas
      // dentro de diálogos, donde un botón infinito rompería el layout.
      elevatedButtonTheme: _bigButtonTheme,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
    );
  }

  /// Tipografía de marca (Inter): legible en pantallas chicas y con
  /// buen contraste de pesos entre títulos y texto de cuerpo, algo que
  /// el TextTheme por defecto de Material no ofrece.
  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData(brightness: Brightness.dark).textTheme
        : ThemeData(brightness: Brightness.light).textTheme;

    return GoogleFonts.interTextTheme(base).copyWith(
      headlineMedium: GoogleFonts.inter(
        textStyle: base.headlineMedium,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: GoogleFonts.inter(
        textStyle: base.titleLarge,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.inter(
        textStyle: base.titleMedium,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(
        textStyle: base.bodyLarge,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: base.bodyMedium,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.inter(
        textStyle: base.labelLarge,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static final ElevatedButtonThemeData _bigButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      // Material 3 no rellena el ElevatedButton con el color primario por
      // defecto (usa un gris de superficie con texto de color), así que
      // sin esto el botón principal ("Cobrar", "Confirmar", etc.) queda
      // prácticamente invisible sobre el fondo.
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      disabledBackgroundColor: primaryColor.withOpacity(0.3),
      disabledForegroundColor: Colors.white.withOpacity(0.6),
      minimumSize: const Size(double.infinity, 56), // botones grandes
      elevation: 0,
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
    ),
  );
}
