import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Generado por `flutterfire configure` (ver README, sección 4)

import 'core/theme/app_theme.dart';
import 'core/di/providers.dart';
import 'presentation/auth/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final container = ProviderContainer();
  // Arranca la sincronización en segundo plano: sube lo pendiente ahora
  // mismo si hay internet, y se re-suscribe para subir automáticamente
  // cada vez que vuelva la conexión.
  await container.read(syncServiceProvider).iniciar();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HortalizasPosApp(),
    ),
  );
}

class HortalizasPosApp extends StatelessWidget {
  const HortalizasPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hortalizas POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const LoginScreen(),
      // TODO Fase 4 (mejora): si `authServiceProvider.usuarioActual` ya tiene
      // sesión guardada al abrir la app, saltar directo a la pantalla del rol
      // correspondiente en vez de mostrar el login de nuevo (agregar un
      // widget "AuthGate" con StreamBuilder sobre authStateProvider, que hoy
      // no existe todavía).
    );
  }
}
