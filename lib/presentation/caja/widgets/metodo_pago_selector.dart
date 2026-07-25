import 'package:flutter/material.dart';
import '../../../domain/entities/venta.dart';

/// Selector de método de pago: Efectivo, Transferencia, Débito, Crédito.
class MetodoPagoSelector extends StatelessWidget {
  final MetodoPago? seleccionado;
  final ValueChanged<MetodoPago> onChanged;

  const MetodoPagoSelector({super.key, required this.seleccionado, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: MetodoPago.values.map((m) {
        return ChoiceChip(
          label: Text(_label(m)),
          selected: seleccionado == m,
          onSelected: (_) => onChanged(m),
        );
      }).toList(),
    );
  }

  String _label(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.transferencia => 'Transferencia',
        MetodoPago.debito => 'Débito',
        MetodoPago.credito => 'Crédito',
      };
}
