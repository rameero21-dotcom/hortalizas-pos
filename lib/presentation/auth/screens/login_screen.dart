import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/sesion_prefs.dart';
import '../../../core/services/cuentas_recientes.dart';
import '../../../domain/entities/usuario.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../caja/screens/caja_home_screen.dart';
import '../../vendedor/screens/nueva_venta_screen.dart';

/// Pantalla de login. Según el rol del usuario autenticado (Firebase Auth
/// + Firestore), navega a NuevaVentaScreen (vendedor), CajaHomeScreen
/// (cajero) o AdminDashboardScreen (administrador). El checkbox
/// "Mantener sesión iniciada" decide si la próxima vez que se abra la
/// app va a entrar directo (sin pedir usuario/contraseña) o no.
///
/// Las "cuentas recientes" permiten cambiar de usuario con un solo
/// toque: la contraseña queda guardada de forma cifrada en el
/// dispositivo (Keystore de Android / almacén de Windows), así que al
/// tocar una cuenta se inicia sesión directo, sin escribir nada de
/// nuevo.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _cargando = false;
  bool _mantenerSesion = true;
  String? _error;
  List<CuentaReciente> _cuentasRecientes = [];

  @override
  void initState() {
    super.initState();
    SesionPrefs.obtenerMantenerSesion().then((valor) {
      if (mounted) setState(() => _mantenerSesion = valor);
    });
    _cargarCuentasRecientes();
  }

  Future<void> _cargarCuentasRecientes() async {
    final cuentas = await CuentasRecientes.obtener();
    if (mounted) setState(() => _cuentasRecientes = cuentas);
  }

  /// Al tocar una cuenta reciente, intenta entrar directo con la
  /// contraseña guardada. Si por algún motivo no hay contraseña guardada
  /// (o cambió y ya no es válida), cae al modo normal: precarga el email
  /// y deja que escriban la contraseña una vez más.
  Future<void> _elegirCuenta(CuentaReciente cuenta) async {
    final passwordGuardada = await CuentasRecientes.obtenerPassword(cuenta.email);
    if (passwordGuardada == null) {
      setState(() {
        _emailCtrl.text = cuenta.email;
        _passwordCtrl.clear();
        _error = null;
      });
      _passwordFocus.requestFocus();
      return;
    }

    setState(() {
      _emailCtrl.text = cuenta.email;
      _passwordCtrl.text = passwordGuardada;
      _error = null;
    });
    await _login();
  }

  Future<void> _quitarCuenta(CuentaReciente cuenta) async {
    await CuentasRecientes.quitar(cuenta.email);
    _cargarCuentasRecientes();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
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
      await SesionPrefs.guardarMantenerSesion(_mantenerSesion);
      await CuentasRecientes.agregar(
        CuentaReciente(
          email: usuario.email,
          nombre: usuario.nombre,
          rol: _labelRol(usuario.rol),
        ),
        _passwordCtrl.text,
      );
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

  String _labelRol(RolUsuario rol) => switch (rol) {
        RolUsuario.administrador => 'Administrador',
        RolUsuario.vendedor => 'Vendedor',
        RolUsuario.cajero => 'Cajero',
      };

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
        child: ListView(
          children: [
            const SizedBox(height: 24),
            Center(
              child: Image.asset('assets/images/logo.png', height: 96, errorBuilder: (_, __, ___) =>
                  const Icon(Icons.storefront, size: 96)),
            ),
            const SizedBox(height: 24),
            if (_cuentasRecientes.isNotEmpty) ...[
              const Text('Cuentas recientes', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cuentasRecientes.length,
                        separatorBuilder: (context, i) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final c = _cuentasRecientes[i];
                          return GestureDetector(
                            onTap: () => _elegirCuenta(c),
                            onLongPress: () => _quitarCuenta(c),
                            child: Container(
                              width: 110,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text(c.nombre.isNotEmpty ? c.nombre[0] : '?'),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c.nombre,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(c.rol,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Text('Tocá para entrar directo · mantené presionado para quitar',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 24),
            ],
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              focusNode: _passwordFocus,
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              obscureText: true,
              onSubmitted: (_) => _login(),
            ),
            CheckboxListTile(
              value: _mantenerSesion,
              onChanged: (v) => setState(() => _mantenerSesion = v ?? true),
              title: const Text('Mantener sesión iniciada'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
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
