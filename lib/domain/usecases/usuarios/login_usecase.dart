import '../../entities/usuario.dart';
import '../../repositories/usuario_repository.dart';

class LoginUseCase {
  final UsuarioRepository _usuarioRepository;
  LoginUseCase(this._usuarioRepository);

  Future<Usuario?> call(String email, String password) {
    return _usuarioRepository.login(email, password);
  }
}
