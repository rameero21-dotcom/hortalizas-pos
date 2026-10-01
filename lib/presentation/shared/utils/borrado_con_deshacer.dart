import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Agrega "deshacer" a un borrado por swipe: el ítem desaparece de la
/// lista al toque (optimista, vía [idsOcultos]) y recién se llama al
/// borrado real si pasan 4 segundos sin que se toque "Deshacer" en el
/// snackbar que aparece.
///
/// Si se sale de la pantalla antes de que termine la espera, el
/// borrado pendiente se confirma igual (no se cancela silenciosamente)
/// — así nunca queda un ítem que el usuario cree eliminado pero en
/// realidad sigue existiendo en Firestore.
mixin BorradoConDeshacerMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final Set<String> _ocultos = {};
  final Map<String, Timer> _timers = {};
  final Map<String, Future<void> Function()> _pendientes = {};

  /// IDs ocultos de la lista mientras esperan a confirmarse o deshacerse.
  Set<String> get idsOcultos => _ocultos;

  void eliminarConDeshacer({
    required String id,
    required String mensaje,
    required Future<void> Function() eliminar,
    VoidCallback? alConfirmar,
  }) {
    setState(() => _ocultos.add(id));
    _pendientes[id] = eliminar;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _deshacer(id),
        ),
      ),
    );

    _timers[id] = Timer(const Duration(seconds: 4), () => _confirmar(id, alConfirmar));
  }

  void _deshacer(String id) {
    _timers.remove(id)?.cancel();
    _pendientes.remove(id);
    if (mounted) setState(() => _ocultos.remove(id));
  }

  void _confirmar(String id, VoidCallback? alConfirmar) {
    _timers.remove(id);
    final accion = _pendientes.remove(id);
    accion?.call();
    if (mounted) setState(() => _ocultos.remove(id));
    alConfirmar?.call();
  }

  @override
  void dispose() {
    for (final id in _timers.keys.toList()) {
      _timers.remove(id)?.cancel();
      _pendientes.remove(id)?.call();
    }
    super.dispose();
  }
}
