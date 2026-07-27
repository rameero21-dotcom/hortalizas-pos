import 'package:flutter/material.dart';
import '../../../domain/entities/detalle_venta.dart';
import '../../../core/utils/formatters.dart';

/// Fila de un producto ya agregado a la venta en curso.
/// Ejemplo (según especificación):
///   Papa
///   Cantidad: 5
///   Precio: $45.000
///   [Eliminar] [Editar]
class ItemCarritoTile extends StatelessWidget {
  final DetalleVenta item;
  final VoidCallback onEliminar;
  final VoidCallback onEditar;

  const ItemCarritoTile({
    super.key,
    required this.item,
    required this.onEliminar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(item.nombreProducto, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Cantidad: ${Formatters.formatearCantidad(item.cantidad)}\nPrecio: ${Formatters.formatearMoneda(item.precioTotal)}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: onEditar),
            IconButton(icon: const Icon(Icons.delete), onPressed: onEliminar),
          ],
        ),
      ),
    );
  }
}
