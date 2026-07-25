import '../../entities/cliente.dart';
import '../../repositories/cliente_repository.dart';

class GestionarClientesUseCase {
  final ClienteRepository _clienteRepository;
  GestionarClientesUseCase(this._clienteRepository);

  Future<void> crear(Cliente cliente) => _clienteRepository.crear(cliente);
  Future<void> actualizar(Cliente cliente) => _clienteRepository.actualizar(cliente);
  Future<void> eliminar(String id) => _clienteRepository.eliminar(id);
}
