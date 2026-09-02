import '../../core/errors/failures.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/repositories/usuario_repository.dart';
import '../datasources/local/usuario_local_datasource.dart';
import '../datasources/remote/auth_service.dart';
import '../datasources/remote/firestore_service.dart';
import '../models/usuario_model.dart';

/// Login real con Firebase Auth: autentica por email/password y luego
/// busca el rol del usuario en Firestore (colección "usuarios", mismo
/// id que el uid de Firebase Auth). El usuario se cachea en SQLite para
/// poder mostrar su nombre/rol sin conexión en sesiones siguientes.
class UsuarioRepositoryImpl implements UsuarioRepository {
  final UsuarioLocalDatasource _local;
  final AuthService _authService;
  final FirestoreService _firestoreService;

  UsuarioRepositoryImpl(this._local, this._authService, this._firestoreService);

  @override
  Future<Usuario?> login(String email, String password) async {
    final user = await _authService.login(email, password);
    if (user == null) throw const FailureAutenticacion('No se pudo iniciar sesión');

    final doc = await _firestoreService.usuarios.doc(user.uid).get();
    if (!doc.exists) {
      throw const FailureAutenticacion(
        'El usuario no tiene un perfil cargado en el sistema. Pedile al administrador que lo cree en Firestore (colección "usuarios", documento con el mismo id que el UID de Firebase Auth).',
      );
    }

    final data = doc.data() as Map<String, dynamic>;
    final usuarioModel = UsuarioModel.fromMap({'id': user.uid, ...data});
    await _local.upsert(usuarioModel);
    return usuarioModel;
  }

  @override
  Future<void> logout() => _authService.logout();

  @override
  Future<Usuario?> usuarioActual() async {
    final user = _authService.usuarioActual;
    if (user == null) return null;
    final todos = await _local.obtenerTodos();
    try {
      return todos.firstWhere((u) => u.id == user.uid);
    } catch (_) {
      return null; // logueado en Firebase pero sin caché local (ej. reinstaló la app)
    }
  }

  @override
  Future<List<Usuario>> obtenerTodos() async {
    // Antes esto solo leía la caché local, que únicamente tiene los
    // usuarios que alguna vez iniciaron sesión EN ESTE dispositivo — un
    // admin nuevo, o uno que nunca usó esta PC/celular, no aparecía en
    // la lista aunque sí existiera en Firestore. Ahora se trae la
    // lista completa real.
    final snap = await _firestoreService.usuarios.get();
    return snap.docs
        .map((d) => UsuarioModel.fromMap({'id': d.id, ...d.data() as Map<String, dynamic>}))
        .toList();
  }

  /// Stream en tiempo real de la lista completa de usuarios.
  Stream<List<Usuario>> observarTodos() {
    return _firestoreService.usuarios.snapshots().map((snap) => snap.docs
        .map((d) => UsuarioModel.fromMap({'id': d.id, ...d.data() as Map<String, dynamic>}))
        .toList());
  }

  @override
  Future<void> crear(Usuario usuario, String password) async {
    // TODO Fase 4 (admin crea usuarios): requiere Firebase Admin SDK o
    // Cloud Function, porque crear un usuario de Auth desde el cliente
    // móvil desloguearía al admin actual. Ver README sección "Crear usuarios".
    throw UnimplementedError('crear usuario - Fase 4 (requiere Cloud Function)');
  }

  @override
  Future<void> actualizar(Usuario usuario) async {
    throw UnimplementedError('actualizar usuario - Fase 4 (admin)');
  }

  @override
  Future<void> eliminar(String id) async {
    throw UnimplementedError('eliminar usuario - Fase 4 (admin)');
  }
}
