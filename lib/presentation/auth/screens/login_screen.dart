import 'package:flutter/material.dart';
import '../../shared/widgets/gradient_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/sesion_prefs.dart';
import '../../../core/services/cuentas_recientes.dart';
import '../../../domain/entities/usuario.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../caja/screens/caja_home_screen.dart';
import '../../vendedor/screens/nueva_venta_screen.dart';
import '../../shared/widgets/loading_widget.dart';

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
    if (!mounted) return;
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
        if (!mounted) return;
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
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al iniciar sesión: $e');
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

  Widget _campoLabel(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
            color: Color(0xFF8B8B93),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const GradientAppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ListView(
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 22,
                  errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  'HORTALIZAS POS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Bienvenido',
                style: textTheme.displayMedium?.copyWith(fontSize: 30, letterSpacing: -0.3)),
            const SizedBox(height: 6),
            Text('Ingresá para continuar', style: textTheme.bodyMedium),
            const SizedBox(height: 28),
            if (_cuentasRecientes.isNotEmpty) ...[
              Text('Cuentas recientes', style: AppTheme.eyebrowStyle(context)),
              const SizedBox(height: 12),
              SizedBox(
                height: 92,
                child: _cargando
                    ? const LoadingWidget()
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cuentasRecientes.length,
                        separatorBuilder: (context, i) => const SizedBox(width: 18),
                        itemBuilder: (context, i) {
                          final c = _cuentasRecientes[i];
                          return GestureDetector(
                            onTap: () => _elegirCuenta(c),
                            onLongPress: () => _quitarCuenta(c),
                            child: SizedBox(
                              width: 72,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE4E1D8)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                                      style: textTheme.displayMedium
                                          ?.copyWith(fontSize: 15, letterSpacing: 0),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(c.nombre,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 28),
            ],
            _campoLabel('Usuario'),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'usuario@ejemplo.com'),
            ),
            const SizedBox(height: 18),
            _campoLabel('Contraseña'),
            TextField(
              controller: _passwordCtrl,
              focusNode: _passwordFocus,
              decoration: const InputDecoration(hintText: '••••••••'),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _cargando ? null : _login,
              child: _cargando
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Ingresar'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
