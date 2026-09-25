import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema de la aplicación con los colores de marca de C&S Hortalizas:
/// azul (#1226A9, el de "C&S" en el logo) como color principal, y
/// naranja (#FE9015, el de "HORTALIZAS PESADAS") como acento para
/// destacar montos importantes y llamadas a la acción.
///
/// El modo claro usa una paleta "premium" (marfil cálido, tinta casi
/// negra, degradés fuera) en vez del blanco/gris frío genérico de
/// Material — pensada tomando como referencia apps del rubro con
/// mucho cuidado de diseño (Square, Stripe) en vez de un dashboard
/// SaaS genérico. El modo oscuro no se toca: sigue disponible pero
/// `main.dart` fuerza claro como default ahora.
///
/// `light` y `dark` se arman con la misma función (`_build`) para que
/// nunca vuelvan a desalinearse entre sí: cualquier ajuste de card,
/// appbar, inputs o botones se aplica a los dos modos por igual.
class AppTheme {
  static const Color primaryColor = Color(0xFF1226A9); // Azul de marca
  static const Color secondaryColor = Color(0xFFFE9015); // Naranja de marca
  static const Color successColor = Color(0xFF2F7D5A); // Verde apagado (utilidad, stock OK)
  static const Color dangerColor = Color(0xFFC0392B); // Rojo apagado (sin stock, saldo negativo)

  // Radios de borde unificados: mismo lenguaje visual en toda la app
  // (inputs más chicos que botones, botones más chicos que cards).
  static const double radiusInput = 12;
  static const double radiusButton = 12;
  static const double radiusCard = 16;

  // Paleta clara: marfil cálido en vez de blanco/gris frío, y una
  // tinta casi negra (no #000 puro) para el texto — la misma lógica
  // tonal que usan las apps de punto de venta/hospitalidad de gama
  // alta, en vez del azul-sobre-blanco de un dashboard SaaS genérico.
  static const Color _fondoClaro = Color(0xFFFAF9F6);
  static const Color _superficieClara = Colors.white;
  static const Color _inkColor = Color(0xFF14151A);
  static const Color _inkMutedColor = Color(0xFF6E6E76);

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
        isDark ? Colors.white.withOpacity(0.07) : _inkColor.withOpacity(0.09);
    // Botón principal: tinta casi negra en claro (el look "premium" que
    // se aprobó), azul de marca en oscuro (tinta sobre fondo oscuro no
    // tendría casi contraste).
    final colorBoton = isDark ? primaryColor : _inkColor;
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
        onSurface: isDark ? null : _inkColor,
        onSurfaceVariant: isDark ? null : _inkMutedColor,
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
      // Encabezado plano, heredando el color del fondo (marfil en
      // claro) en vez del degradé de marca que tenía antes: el
      // rediseño premium separa las pantallas con líneas finas, no
      // con bloques de color.
      appBarTheme: AppBarTheme(
        backgroundColor: fondo,
        foregroundColor: isDark ? Colors.white : _inkColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: isDark ? Colors.white : _inkColor,
          fontWeight: FontWeight.w600,
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
        backgroundColor: isDark ? _superficieOscura : _inkColor,
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
      elevatedButtonTheme: _buildBigButtonTheme(colorBoton),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          side: BorderSide(color: bordeSutil),
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

  /// Tipografía de marca: Inter para toda la interfaz, y Fraunces (una
  /// serif editorial) reservada solo para los montos grandes de cada
  /// pantalla (`textTheme.displayMedium`) — el total del día, el total
  /// de una venta. Se usa en un solo lugar por pantalla a propósito:
  /// es lo que hace que se sienta diseñado, no una fuente decorativa
  /// repetida en todos lados.
  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData(brightness: Brightness.dark).textTheme
        : ThemeData(brightness: Brightness.light).textTheme;

    return GoogleFonts.interTextTheme(base).copyWith(
      displayMedium: GoogleFonts.fraunces(
        textStyle: base.displayMedium,
        fontSize: 36,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
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

  /// Micro-label en versalitas trackeadas (ej. "HOY", "ACCESOS") — el
  /// recurso tipográfico que reemplaza los títulos de sección en
  /// negrita suelta por algo más editorial/premium.
  static TextStyle eyebrowStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.inter(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      color: isDark ? Colors.white54 : const Color(0xFFB4B2A8),
    );
  }

  static ElevatedButtonThemeData _buildBigButtonTheme(Color colorBoton) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        // Material 3 no rellena el ElevatedButton con el color primario
        // por defecto (usa un gris de superficie con texto de color),
        // así que sin esto el botón principal queda casi invisible.
        backgroundColor: colorBoton,
        foregroundColor: Colors.white,
        disabledBackgroundColor: colorBoton.withOpacity(0.3),
        disabledForegroundColor: Colors.white.withOpacity(0.6),
        minimumSize: const Size(double.infinity, 56), // botones grandes
        elevation: 0,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
      ),
    );
  }
}
