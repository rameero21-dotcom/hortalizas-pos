import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pantalla de bienvenida mostrada mientras AuthGate decide a qué
/// pantalla ir (sesión guardada, rol del usuario, etc.).
///
/// No es un splash nativo — no tapa el primer frame en blanco que el
/// sistema operativo muestra antes de que Flutter arranque a dibujar,
/// para eso hay que configurar cada plataforma por separado (y este
/// proyecto no tiene las carpetas android/ios/windows versionadas) —
/// pero cubre el momento real de espera de la app con la marca en vez
/// de un spinner pelado sobre fondo negro.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1030),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 64,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.storefront, size: 56, color: Colors.white),
            ).animate().fadeIn(duration: 400.ms).scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                  curve: Curves.easeOut,
                ),
            const SizedBox(height: 26),
            Text(
              'Hortalizas',
              style: GoogleFonts.fraunces(
                fontSize: 34,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFF8F7F3),
                letterSpacing: -0.3,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
            const SizedBox(height: 10),
            Text(
              'PUNTO DE VENTA',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 3.2,
                color: Colors.white.withOpacity(0.5),
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 22),
            Container(width: 32, height: 1, color: const Color(0xFFFE9015).withOpacity(0.85))
                .animate()
                .fadeIn(delay: 400.ms, duration: 300.ms),
          ],
        ),
      ),
    );
  }
}
