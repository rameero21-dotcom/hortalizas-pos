import '../entities/cliente.dart';

/// Contrato del repositorio de Clientes (preparado para el futuro).
abstract class ClienteRepository {
  Future<List<Cliente>> obtenerTodos();
  Future<Cliente?> obtenerPorId(String id);
  Future<void> crear(Cliente cliente);
  Future<void> actualizar(Cliente cliente);
  Future<void> eliminar(String id);
}
