import 'package:connectivity_plus/connectivity_plus.dart';

/// Expone el estado de conectividad y notifica cambios para disparar
/// la sincronización automática cuando vuelve la conexión a internet.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));

  Future<bool> hayConexion() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
