import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'core/di/providers.dart';
import 'presentation/auth/screens/auth_gate.dart';
import 'presentation/shared/providers/theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Si esto falla (por ejemplo, sin conexión en el primerísimo arranque
  // de un dispositivo que todavía no tiene nada guardado localmente), la
  // app entera se cerraba de golpe sin ningún aviso. Ahora se muestra
  // una pantalla explicando qué pasó, en vez de un cierre silencioso.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(_ErrorInicioApp(error: e.toString()));
    return;
  }

  final container = ProviderContainer();
  await container.read(syncServiceProvider).iniciar();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HortalizasPosApp(),
    ),
  );
}

/// Pantalla mínima que se muestra si la app no pudo arrancar porque
/// falló la conexión inicial con Firebase (normalmente: sin internet en
/// el primer uso de este dispositivo, antes de tener algo guardado
/// localmente).
class _ErrorInicioApp extends StatelessWidget {
  final String error;
  const _ErrorInicioApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 56, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo conectar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este dispositivo necesita conexión a internet la primera vez que se abre la app. '
                  'Conectate a wifi o datos móviles y volvé a intentar.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(error, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HortalizasPosApp extends ConsumerWidget {
  const HortalizasPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El modo (claro/oscuro) lo elige el usuario con el botón de sol/
    // luna en el panel de admin y en caja, y se guarda entre aperturas
    // de la app (ver theme_mode_provider.dart). Por defecto arranca en
    // claro: es el tema "premium" (marfil, tinta, Fraunces) pensado
    // como principal.
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Hortalizas POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}