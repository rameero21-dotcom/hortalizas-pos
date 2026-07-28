import 'package:flutter/material.dart';
import '../../../domain/entities/venta.dart';

/// Selector de método de pago: Efectivo, Transferencia, Cuenta corriente
/// (fiado). Débito y Crédito no se ofrecen como opción (el negocio no
/// las usa), pero el enum MetodoPago los conserva por compatibilidad
/// con datos viejos ya guardados.
class MetodoPagoSelector extends StatelessWidget {
  final MetodoPago? seleccionado;
  final ValueChanged<MetodoPago> onChanged;

  const MetodoPagoSelector({super.key, required this.seleccionado, required this.onChanged});

  static const _opciones = [MetodoPago.efectivo, MetodoPago.transferencia, MetodoPago.cuentaCorriente];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _opciones.map((m) {
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
        MetodoPago.cuentaCorriente => 'Cuenta corriente (fiado)',
      };
}
