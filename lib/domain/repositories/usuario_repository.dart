import '../entities/usuario.dart';

/// Contrato del repositorio de Usuarios / Autenticación.
abstract class UsuarioRepository {
  Future<Usuario?> login(String email, String password);
  Future<void> logout();
  Future<Usuario?> usuarioActual();
  Future<List<Usuario>> obtenerTodos();

  /// Stream en tiempo real de la lista completa de usuarios.
  Stream<List<Usuario>> observarTodos();
  Future<void> crear(Usuario usuario, String password);
  Future<void> actualizar(Usuario usuario);
  Future<void> eliminar(String id);
}
