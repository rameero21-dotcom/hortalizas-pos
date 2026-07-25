import '../../domain/entities/usuario.dart';

class UsuarioModel extends Usuario {
  const UsuarioModel({
    required super.id,
    required super.nombre,
    required super.email,
    required super.rol,
    super.activo,
  });

  /// Acepta tanto filas de SQLite (donde los booleanos se guardan como
  /// 0/1) como documentos de Firestore (donde "activo" es un bool real
  /// como true/false) — el mismo `fromMap` se usa para ambas fuentes.
  factory UsuarioModel.fromMap(Map<String, dynamic> map) => UsuarioModel(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        email: map['email'] as String,
        rol: RolUsuario.values.byName(map['rol'] as String),
        activo: _parseActivo(map['activo']),
      );

  static bool _parseActivo(dynamic valor) {
    if (valor == null) return true;
    if (valor is bool) return valor;
    if (valor is int) return valor == 1;
    return true;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        'rol': rol.name,
        'activo': activo ? 1 : 0,
      };
}
