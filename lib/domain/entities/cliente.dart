/// Entidad de dominio: Cliente (preparado para uso futuro - cuenta corriente).
class Cliente {
  final String id;
  final String nombre;
  final String telefono;
  final String direccion;
  final double saldoCuentaCorriente;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    this.saldoCuentaCorriente = 0,
  });
}
