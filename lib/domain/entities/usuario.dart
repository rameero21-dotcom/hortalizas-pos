enum RolUsuario { administrador, vendedor, cajero }

/// Entidad de dominio: usuario del sistema con su rol y permisos.
class Usuario {
  final String id;
  final String nombre;
  final String email;
  final RolUsuario rol;
  final bool activo;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.activo = true,
  });

  bool get puedeVender => rol == RolUsuario.vendedor || rol == RolUsuario.administrador;
  bool get puedeCobrar => rol == RolUsuario.cajero || rol == RolUsuario.administrador;
  bool get esAdmin => rol == RolUsuario.administrador;
}
