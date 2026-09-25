import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';

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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, Color(0xFF0C1B7A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 120,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.storefront, size: 96, color: Colors.white),
              ).animate().fadeIn(duration: 400.ms).scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1, 1),
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 16),
              const Text(
                'Hortalizas POS',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const SizedBox(height: 40),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
              ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}
