import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/sesion_prefs.dart';
import '../../../domain/entities/usuario.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../caja/screens/caja_home_screen.dart';
import '../../vendedor/screens/nueva_venta_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

/// Se muestra al arrancar la app: decide si hay que ir directo a la
/// pantalla del rol correspondiente (porque quedó una sesión guardada y
/// el usuario eligió "mantener sesión iniciada") o mostrar el login.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _cargando = true;
  Widget? _destino;

  @override
  void initState() {
    super.initState();
    _decidirPantallaInicial();
  }

  Future<void> _decidirPantallaInicial() async {
    LogService.registrar('AuthGate: decidiendo pantalla inicial');
    final mantenerSesion = await SesionPrefs.obtenerMantenerSesion();
    LogService.registrar('AuthGate: mantenerSesion=$mantenerSesion');

    if (!mantenerSesion) {
      // El usuario eligió no mantener la sesión: se cierra explícitamente
      // para que la próxima vez siempre pida usuario y contraseña.
      await ref.read(authServiceProvider).logout();
      LogService.registrar('AuthGate: destino = LoginScreen (sesion no mantenida)');
      if (mounted) setState(() {
        _destino = const LoginScreen();
        _cargando = false;
      });
      return;
    }

    final usuario = await ref.read(usuarioRepositoryProvider).usuarioActual();
    LogService.registrar('AuthGate: usuarioActual=${usuario?.rol}');
    if (usuario == null) {
      LogService.registrar('AuthGate: destino = LoginScreen (sin usuario)');
      if (mounted) setState(() {
        _destino = const LoginScreen();
        _cargando = false;
      });
      return;
    }

    final pantalla = switch (usuario.rol) {
      RolUsuario.administrador => const AdminDashboardScreen(),
      RolUsuario.vendedor => const NuevaVentaScreen(),
      RolUsuario.cajero => const CajaHomeScreen(),
    };
    LogService.registrar('AuthGate: destino = ${usuario.rol}');
    if (mounted) setState(() {
      _destino = pantalla;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const SplashScreen();
    }
    return _destino!;
  }
}
