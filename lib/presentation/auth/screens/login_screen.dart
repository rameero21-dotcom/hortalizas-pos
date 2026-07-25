import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/usuario.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../caja/screens/caja_home_screen.dart';
import '../../vendedor/screens/nueva_venta_screen.dart';

/// Pantalla de login. Según el rol del usuario autenticado (Firebase Auth
/// + Firestore), navega a NuevaVentaScreen (vendedor), CajaHomeScreen
/// (cajero) o AdminDashboardScreen (administrador).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final usuario = await ref.read(loginUseCaseProvider).call(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
      if (usuario == null) {
        setState(() => _error = 'Email o contraseña incorrectos');
        return;
      }
      if (!mounted) return;
      _navegarSegunRol(usuario);
    } on FailureAutenticacion catch (e) {
      setState(() => _error = e.mensaje);
    } catch (e) {
      setState(() => _error = 'Error al iniciar sesión: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _navegarSegunRol(Usuario usuario) {
    final Widget destino = switch (usuario.rol) {
      RolUsuario.administrador => const AdminDashboardScreen(),
      RolUsuario.vendedor => const NuevaVentaScreen(),
      RolUsuario.cajero => const CajaHomeScreen(),
    };
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => destino));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 96, errorBuilder: (_, __, ___) =>
                const Icon(Icons.storefront, size: 96)),
            const SizedBox(height: 24),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              obscureText: true,
              onSubmitted: (_) => _login(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _cargando ? null : _login,
              child: _cargando
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Ingresar'),
            ),
          ],
        ),
      ),
    );
  }
}
