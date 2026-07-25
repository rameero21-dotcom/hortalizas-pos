import 'package:firebase_auth/firebase_auth.dart';

/// Wrapper sobre Firebase Authentication.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get usuarioActual => _auth.currentUser;

  Future<User?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  Future<void> logout() => _auth.signOut();

  Stream<User?> get onAuthStateChanged => _auth.authStateChanges();
}
