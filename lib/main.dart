import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'core/di/providers.dart';
import 'core/services/log_service.dart';
import 'presentation/auth/screens/auth_gate.dart';
import 'presentation/shared/providers/theme_mode_provider.dart';

/// Si la app se cierra o se queda trabada sin mostrar ningún mensaje de
/// error (pasó en Windows), no hay nada para sacarle una foto. Por eso
/// cada paso del arranque queda anotado en LogService (ver ese archivo
/// para dónde se guarda) — así, la próxima vez, el archivo dice hasta
/// dónde llegó a arrancar antes de lo que haya pasado.
Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    LogService.registrar('=== Arranca la app ===');

    FlutterError.onError = (details) {
      LogService.registrar('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      LogService.registrar('Error no capturado: $error\n$stack');
      return true;
    };

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    LogService.registrar('sqflite listo');

    // Si esto falla (por ejemplo, sin conexión en el primerísimo arranque
    // de un dispositivo que todavía no tiene nada guardado localmente), la
    // app entera se cerraba de golpe sin ningún aviso. Ahora se muestra
    // una pantalla explicando qué pasó, en vez de un cierre silencioso.
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      LogService.registrar('Firebase inicializado');
    } catch (e) {
      LogService.registrar('Firebase fallo al inicializar: $e');
      runApp(_ErrorInicioApp(error: e.toString()));
      return;
    }

    final container = ProviderContainer();
    await container.read(syncServiceProvider).iniciar();
    LogService.registrar('Servicio de sincronizacion iniciado');

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const HortalizasPosApp(),
      ),
    );
    LogService.registrar('runApp llamado');
  }, (error, stack) {
    LogService.registrar('Excepcion en zona no capturada: $error\n$stack');
  });
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