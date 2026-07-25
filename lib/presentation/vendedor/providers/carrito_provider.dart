import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/detalle_venta.dart';

/// Estado del carrito de la venta en curso (antes de finalizar).
class CarritoNotifier extends StateNotifier<List<DetalleVenta>> {
  CarritoNotifier() : super([]);

  void agregarProducto(DetalleVenta item) {
    state = [...state, item];
  }

  void eliminarProducto(int index) {
    final nuevaLista = [...state]..removeAt(index);
    state = nuevaLista;
  }

  void editarProducto(int index, DetalleVenta item) {
    final nuevaLista = [...state];
    nuevaLista[index] = item;
    state = nuevaLista;
  }

  double get total => state.fold(0.0, (sum, item) => sum + item.precioTotal);

  void limpiar() => state = [];
}

final carritoProvider = StateNotifierProvider<CarritoNotifier, List<DetalleVenta>>(
  (ref) => CarritoNotifier(),
);
