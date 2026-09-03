/// Constantes globales de la aplicación.
class AppConstants {
  static const String appName = 'Hortalizas POS';
  static const String nombreComercio = 'Mi Comercio de Hortalizas'; // TODO: hacer configurable

  // Colecciones de Firestore
  static const String colProductos = 'productos';
  static const String colVentas = 'ventas';
  static const String colStock = 'stock';
  static const String colUsuarios = 'usuarios';
  static const String colClientes = 'clientes';
  static const String colMovimientosStock = 'movimientos_stock';
  static const String colMovimientosCaja = 'movimientos_caja';
  static const String colCierresCaja = 'cierres_caja';
  static const String colMovimientosCuentaCorriente = 'movimientos_cuenta_corriente';
  static const String colProveedores = 'proveedores';
  static const String colPedidosProveedor = 'pedidos_proveedor';
  static const String colPagosProveedor = 'pagos_proveedor';
  static const String colFacturacionMarcados = 'facturacion_marcados';
  static const String colFacturacionOcultos = 'facturacion_ocultos';
  static const String colConfiguracion = 'configuracion';

  // Tablas SQLite
  static const String tablaProductos = 'productos';
  static const String tablaVentas = 'ventas';
  static const String tablaDetalleVenta = 'detalle_venta';
  static const String tablaStock = 'stock';
  static const String tablaClientes = 'clientes';
  static const String tablaUsuarios = 'usuarios';
  static const String tablaProveedores = 'proveedores';
  static const String tablaPedidosProveedor = 'pedidos_proveedor';
  static const String tablaSyncQueue = 'sync_queue'; // cola de cambios pendientes de sincronizar

  // Stock bajo (alerta) - umbral por defecto, override por producto
  static const double umbralStockBajoDefault = 10.0;

  // Impresora
  static const int anchoTicket58mm = 384; // dots
  static const int anchoTicket80mm = 576; // dots
}
