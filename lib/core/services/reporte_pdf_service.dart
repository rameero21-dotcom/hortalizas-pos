import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/venta.dart';
import '../../domain/entities/caja.dart';
import '../../domain/entities/cliente.dart';
import '../../domain/usecases/estadisticas/obtener_estadisticas_usecase.dart';
import '../utils/formatters.dart';

/// Genera un reporte en PDF con todos los movimientos del negocio en un
/// rango de fechas: facturación, costo/impuestos/utilidad, ventas por
/// método de pago, ingresos/egresos manuales de caja, productos
/// vendidos, y cómo evolucionó la cuenta corriente de cada cliente.
///
/// Se arma en el propio dispositivo (celular o PC) con los datos que ya
/// se trajeron de Firestore para esa consulta — no hace ningún pedido
/// de red extra acá adentro, solo da formato.
class ReportePdfService {
  Future<Uint8List> generar({
    required DateTime desde,
    required DateTime hasta,
    required List<Venta> ventas, // ya filtradas a "cobrada" y al rango
    required EstadisticasResumen estadisticas,
    required List<MovimientoCaja> movimientosCaja,
    required List<Cliente> clientes,
    required List<MovimientoCuentaCorriente> movimientosCuentaCorriente,
  }) async {
    final doc = pw.Document();

    final ingresosManuales = movimientosCaja.where((m) => m.tipo == TipoMovimientoCaja.ingreso).toList();
    final egresosManuales = movimientosCaja.where((m) => m.tipo == TipoMovimientoCaja.egreso).toList();
    final totalIngresos = ingresosManuales.fold(0.0, (acc, m) => acc + m.monto);
    final totalEgresos = egresosManuales.fold(0.0, (acc, m) => acc + m.monto);

    final facturacionPorMetodo = <String, double>{};
    final cantidadPorMetodo = <String, int>{};
    for (final v in ventas) {
      final pagos = v.pagos.isNotEmpty
          ? v.pagos
          : (v.metodoPago != null ? [DetallePago(metodo: v.metodoPago!, monto: v.total)] : <DetallePago>[]);
      for (final p in pagos) {
        final label = _labelMetodo(p.metodo);
        facturacionPorMetodo.update(label, (a) => a + p.monto, ifAbsent: () => p.monto);
        cantidadPorMetodo.update(label, (a) => a + 1, ifAbsent: () => 1);
      }
    }

    // Cuenta corriente: cargos y pagos DENTRO del período, por cliente,
    // más el saldo actual (al momento de generar el reporte).
    final movsPorCliente = <String, List<MovimientoCuentaCorriente>>{};
    for (final m in movimientosCuentaCorriente) {
      movsPorCliente.putIfAbsent(m.clienteId, () => []).add(m);
    }
    final filasCuentaCorriente = <List<String>>[];
    for (final cliente in clientes) {
      final movs = movsPorCliente[cliente.id] ?? [];
      if (movs.isEmpty) continue;
      final cargos = movs.where((m) => m.tipo == TipoMovimientoCuenta.cargo).fold(0.0, (a, m) => a + m.monto);
      final pagos = movs.where((m) => m.tipo == TipoMovimientoCuenta.pago).fold(0.0, (a, m) => a + m.monto);
      filasCuentaCorriente.add([
        cliente.nombre,
        Formatters.formatearMoneda(cargos),
        Formatters.formatearMoneda(pagos),
        Formatters.formatearMoneda(cliente.saldoCuentaCorriente),
      ]);
    }

    final productosOrdenados = estadisticas.resumenPorProducto.values.toList()
      ..sort((a, b) => b.facturacion.compareTo(a.facturacion));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Reporte del negocio', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              '${Formatters.formatearFecha(desde)} — ${Formatters.formatearFecha(hasta.subtract(const Duration(days: 1)))}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generado el ${Formatters.formatearFechaHora(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        build: (context) => [
          _seccion('Resumen general'),
          _tablaResumen([
            ['Facturación total', Formatters.formatearMoneda(estadisticas.facturacionTotal)],
            ['Cantidad de ventas', '${estadisticas.cantidadVentas}'],
            ['Promedio por venta', Formatters.formatearMoneda(estadisticas.promedioPorVenta)],
            ['Costo total', Formatters.formatearMoneda(estadisticas.costoTotalGeneral)],
            ['IIBB', Formatters.formatearMoneda(estadisticas.iibbTotalGeneral)],
            ['TSH', Formatters.formatearMoneda(estadisticas.tshTotalGeneral)],
            ['Utilidad total', Formatters.formatearMoneda(estadisticas.utilidadTotalGeneral)],
          ]),
          pw.SizedBox(height: 16),

          _seccion('Ventas por método de pago'),
          _tablaSimple(
            encabezados: ['Método', 'Cantidad', 'Monto'],
            filas: facturacionPorMetodo.entries
                .map((e) => [e.key, '${cantidadPorMetodo[e.key]}', Formatters.formatearMoneda(e.value)])
                .toList(),
          ),
          pw.SizedBox(height: 16),

          _seccion('Movimientos de caja manuales'),
          _tablaResumen([
            ['Ingresos manuales', Formatters.formatearMoneda(totalIngresos)],
            ['Egresos manuales', Formatters.formatearMoneda(totalEgresos)],
          ]),
          if (ingresosManuales.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Detalle de ingresos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            _tablaSimple(
              encabezados: ['Fecha', 'Detalle', 'Método', 'Monto'],
              filas: ingresosManuales
                  .map((m) => [
                        Formatters.formatearFechaHora(m.fecha),
                        m.detalle,
                        m.metodo == MetodoMovimientoCaja.efectivo ? 'Efectivo' : 'Transferencia',
                        Formatters.formatearMoneda(m.monto),
                      ])
                  .toList(),
            ),
          ],
          if (egresosManuales.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Detalle de egresos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            _tablaSimple(
              encabezados: ['Fecha', 'Detalle', 'Monto'],
              filas: egresosManuales
                  .map((m) => [
                        Formatters.formatearFechaHora(m.fecha),
                        m.detalle,
                        Formatters.formatearMoneda(m.monto),
                      ])
                  .toList(),
            ),
          ],
          pw.SizedBox(height: 16),

          _seccion('Productos vendidos'),
          _tablaSimple(
            encabezados: ['Producto', 'Cantidad', 'Facturación', 'Costo', 'Utilidad'],
            filas: productosOrdenados
                .map((p) => [
                      p.nombreProducto,
                      p.cantidadVendida.toStringAsFixed(0),
                      Formatters.formatearMoneda(p.facturacion),
                      Formatters.formatearMoneda(p.costoTotal),
                      Formatters.formatearMoneda(p.utilidad),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),

          if (filasCuentaCorriente.isNotEmpty) ...[
            _seccion('Cuenta corriente de clientes (movimientos en el período)'),
            _tablaSimple(
              encabezados: ['Cliente', 'Cargos (fiado)', 'Pagos', 'Saldo actual'],
              filas: filasCuentaCorriente,
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  String _labelMetodo(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.transferencia => 'Transferencia',
        MetodoPago.debito => 'Débito',
        MetodoPago.credito => 'Crédito',
        MetodoPago.cuentaCorriente => 'Cuenta corriente (fiado)',
      };

  pw.Widget _seccion(String titulo) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(titulo, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _tablaResumen(List<List<String>> filas) {
    return pw.Table(
      columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)},
      children: filas
          .map((f) => pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text(f[0])),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text(f[1], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
              ]))
          .toList(),
    );
  }

  pw.Widget _tablaSimple({required List<String> encabezados, required List<List<String>> filas}) {
    if (filas.isEmpty) {
      return pw.Text('Sin datos en este período.', style: const pw.TextStyle(color: PdfColors.grey600));
    }
    return pw.TableHelper.fromTextArray(
      headers: encabezados,
      data: filas,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    );
  }
}
