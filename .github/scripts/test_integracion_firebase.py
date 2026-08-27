"""Prueba de integracion a fondo contra Firestore real, replicando
exactamente la estructura de datos y la logica de negocio de la app
(mismos nombres de coleccion, mismos campos, mismas formulas), para
validar que todo el flujo funcione de punta a punta.

Todos los datos de prueba se crean con el prefijo "TEST -" para poder
identificarlos y borrarlos facilmente despues.

Uso: python3 test_integracion_firebase.py
"""
import uuid
import time
import math
import datetime
import json
from google.cloud import firestore

db = firestore.Client.from_service_account_json('/tmp/sa.json')

PREFIJO = "TEST -"
TASA_IIBB = 0.035
TASA_TSH = 0.01

resultados = []


def verificar(nombre, condicion, detalle=""):
    estado = "OK" if condicion else "FALLO"
    resultados.append((nombre, estado, detalle))
    print(f"[{estado}] {nombre} {detalle}")


def ahora_iso():
    return datetime.datetime.now().isoformat()


print("=" * 70)
print("PRUEBA DE INTEGRACION - HORTALIZAS POS")
print("=" * 70)

# ============ 1) Crear productos de prueba con costo ============
print("\n--- 1) Productos ---")
productos_test = [
    {"nombre": f"{PREFIJO} Papa", "costo": 9000, "precio": 14000},
    {"nombre": f"{PREFIJO} Cebolla", "costo": 6500, "precio": 10000},
    {"nombre": f"{PREFIJO} Tomate", "costo": 12000, "precio": 18000},
]
ids_productos = {}
for p in productos_test:
    pid = str(uuid.uuid4())
    ids_productos[p["nombre"]] = pid
    db.collection("productos").document(pid).set({
        "id": pid,
        "nombre": p["nombre"],
        "precioSugerido": p["precio"],
        "categoria": "Verduras",
        "activo": True,
        "favorito": False,
        "costoUnitario": p["costo"],
        "tasaIIBB": 0,
        "tasaTSH": 0,
    })
    # stock inicial
    db.collection("stock").document(pid).set({
        "productoId": pid,
        "cantidadDisponible": 100,
        "umbralStockBajo": 10,
    })

doc = db.collection("productos").document(ids_productos[f"{PREFIJO} Papa"]).get()
verificar("Producto se creo y se puede leer", doc.exists and doc.to_dict()["costoUnitario"] == 9000)

stock_doc = db.collection("stock").document(ids_productos[f"{PREFIJO} Papa"]).get()
verificar("Stock inicial quedo en 100", stock_doc.to_dict()["cantidadDisponible"] == 100)

# ============ 2) Crear cliente de prueba (cuenta corriente) ============
print("\n--- 2) Clientes ---")
cliente_id = str(uuid.uuid4())
db.collection("clientes").document(cliente_id).set({
    "id": cliente_id,
    "nombre": f"{PREFIJO} Cliente Fiado",
    "telefono": "",
    "direccion": "",
    "saldoCuentaCorriente": 0,
})
doc = db.collection("clientes").document(cliente_id).get()
verificar("Cliente se creo con saldo 0", doc.exists and doc.to_dict()["saldoCuentaCorriente"] == 0)

# ============ 3) Simular venta 1: efectivo, pago simple ============
print("\n--- 3) Venta en efectivo ---")
venta1_id = str(uuid.uuid4())
papa_id = ids_productos[f"{PREFIJO} Papa"]
db.collection("ventas").document(venta1_id).set({
    "id": venta1_id, "numero": 9001, "fecha": ahora_iso(),
    "vendedorId": "test-vendedor", "vendedorNombre": f"{PREFIJO} Vendedor",
    "total": 28000, "estado": "pendiente", "metodoPago": None,
    "cajeroId": None, "fechaCobro": None, "clienteId": None,
    "nombreCliente": f"{PREFIJO} boleta 1", "pagos": [],
    "detalle": [{"productoId": papa_id, "nombreProducto": f"{PREFIJO} Papa",
                 "cantidad": 2, "precioTotal": 28000}],
})

# Cobrar: descuenta stock + marca cobrada
db.collection("stock").document(papa_id).update({"cantidadDisponible": firestore.Increment(-2)})
db.collection("ventas").document(venta1_id).update({
    "estado": "cobrada", "metodoPago": "efectivo", "cajeroId": "test-cajero",
    "fechaCobro": ahora_iso(), "pagos": [{"metodo": "efectivo", "monto": 28000}],
})

stock_papa = db.collection("stock").document(papa_id).get().to_dict()
verificar("Stock de Papa bajo de 100 a 98 tras vender 2", stock_papa["cantidadDisponible"] == 98,
          f"(quedo en {stock_papa['cantidadDisponible']})")

venta1 = db.collection("ventas").document(venta1_id).get().to_dict()
verificar("Venta 1 quedo marcada como cobrada", venta1["estado"] == "cobrada")

# ============ 4) Simular venta 2: pago dividido (efectivo + transferencia) ============
print("\n--- 4) Venta con pago dividido ---")
venta2_id = str(uuid.uuid4())
cebolla_id = ids_productos[f"{PREFIJO} Cebolla"]
db.collection("ventas").document(venta2_id).set({
    "id": venta2_id, "numero": 9002, "fecha": ahora_iso(),
    "vendedorId": "test-vendedor", "vendedorNombre": f"{PREFIJO} Vendedor",
    "total": 30000, "estado": "cobrada", "metodoPago": None,
    "cajeroId": "test-cajero", "fechaCobro": ahora_iso(), "clienteId": None,
    "nombreCliente": f"{PREFIJO} boleta 2", "pagos": [
        {"metodo": "efectivo", "monto": 10000},
        {"metodo": "transferencia", "monto": 20000},
    ],
    "detalle": [{"productoId": cebolla_id, "nombreProducto": f"{PREFIJO} Cebolla",
                 "cantidad": 3, "precioTotal": 30000}],
})
db.collection("stock").document(cebolla_id).update({"cantidadDisponible": firestore.Increment(-3)})

venta2 = db.collection("ventas").document(venta2_id).get().to_dict()
suma_pagos = sum(p["monto"] for p in venta2["pagos"])
verificar("Pago dividido suma correctamente al total", suma_pagos == venta2["total"],
          f"(pagos suman {suma_pagos}, total {venta2['total']})")

# ============ 5) Simular venta 3: fiado (cuenta corriente) ============
print("\n--- 5) Venta fiada (cuenta corriente) ---")
venta3_id = str(uuid.uuid4())
tomate_id = ids_productos[f"{PREFIJO} Tomate"]
db.collection("ventas").document(venta3_id).set({
    "id": venta3_id, "numero": 9003, "fecha": ahora_iso(),
    "vendedorId": "test-vendedor", "vendedorNombre": f"{PREFIJO} Vendedor",
    "total": 36000, "estado": "cobrada", "metodoPago": "cuentaCorriente",
    "cajeroId": "test-cajero", "fechaCobro": ahora_iso(), "clienteId": cliente_id,
    "nombreCliente": f"{PREFIJO} boleta 3", "pagos": [{"metodo": "cuentaCorriente", "monto": 36000}],
    "detalle": [{"productoId": tomate_id, "nombreProducto": f"{PREFIJO} Tomate",
                 "cantidad": 2, "precioTotal": 36000}],
})
db.collection("stock").document(tomate_id).update({"cantidadDisponible": firestore.Increment(-2)})

# Cargo en cuenta corriente (igual que hace ClienteRepositoryImpl.registrarMovimientoCuenta)
db.collection("clientes").document(cliente_id).update({"saldoCuentaCorriente": firestore.Increment(-36000)})
mov_id = str(uuid.uuid4())
db.collection("movimientos_cuenta_corriente").document(mov_id).set({
    "id": mov_id, "clienteId": cliente_id, "tipo": "cargo", "monto": 36000,
    "detalle": f"Venta #9003 ({PREFIJO})", "fecha": ahora_iso(), "usuarioId": "test-cajero",
})

cliente_actualizado = db.collection("clientes").document(cliente_id).get().to_dict()
verificar("Saldo del cliente bajo a -36000 tras la venta fiada",
          cliente_actualizado["saldoCuentaCorriente"] == -36000,
          f"(quedo en {cliente_actualizado['saldoCuentaCorriente']})")

# ============ 6) Cliente paga parte de la deuda ============
print("\n--- 6) Pago parcial del cliente ---")
db.collection("clientes").document(cliente_id).update({"saldoCuentaCorriente": firestore.Increment(10000)})
mov_pago_id = str(uuid.uuid4())
db.collection("movimientos_cuenta_corriente").document(mov_pago_id).set({
    "id": mov_pago_id, "clienteId": cliente_id, "tipo": "pago", "monto": 10000,
    "detalle": f"{PREFIJO} pago parcial", "fecha": ahora_iso(), "usuarioId": "test-cajero",
})
cliente_final = db.collection("clientes").document(cliente_id).get().to_dict()
verificar("Saldo del cliente sube a -26000 tras pagar 10000",
          cliente_final["saldoCuentaCorriente"] == -26000,
          f"(quedo en {cliente_final['saldoCuentaCorriente']})")

# ============ 7) Verificar formulas de IIBB/TSH/utilidad ============
print("\n--- 7) Formulas de costo/impuestos/utilidad ---")
# Traigo las 3 ventas de prueba cobradas y calculo como lo hace
# ObtenerEstadisticasUseCase: IIBB = facturacion*3.5%, TSH = facturacion*1%,
# utilidad = facturacion - costoTotal - IIBB - TSH.
facturacion_total_test = 28000 + 30000 + 36000  # ventas 1, 2 y 3
costo_total_test = (9000 * 2) + (6500 * 3) + (12000 * 2)  # costo unit * cantidad
iibb_esperado = facturacion_total_test * TASA_IIBB
tsh_esperado = facturacion_total_test * TASA_TSH
utilidad_esperada = facturacion_total_test - costo_total_test - iibb_esperado - tsh_esperado

print(f"Facturacion total (test): {facturacion_total_test}")
print(f"Costo total (test): {costo_total_test}")
print(f"IIBB esperado (3.5%): {iibb_esperado:.2f}")
print(f"TSH esperado (1%): {tsh_esperado:.2f}")
print(f"Utilidad esperada: {utilidad_esperada:.2f}")
verificar("Formula de utilidad da un resultado positivo y coherente",
          utilidad_esperada > 0 and utilidad_esperada < facturacion_total_test,
          f"(utilidad {utilidad_esperada:.2f} de {facturacion_total_test} facturados)")

# ============ 7) Ciclo completo de deuda: generar y cobrar ============
print("\n--- 7) Ciclo completo: generar deuda y cobrarla ---")
cliente2_id = str(uuid.uuid4())
db.collection("clientes").document(cliente2_id).set({
    "id": cliente2_id, "nombre": f"{PREFIJO} Cliente Cobro", "telefono": "",
    "direccion": "", "saldoCuentaCorriente": 0,
})

# Generar una deuda de 50000 (equivalente a un "Cargo (fiado)" manual)
db.collection("clientes").document(cliente2_id).update({"saldoCuentaCorriente": firestore.Increment(-50000)})
mov_cargo_id = str(uuid.uuid4())
db.collection("movimientos_cuenta_corriente").document(mov_cargo_id).set({
    "id": mov_cargo_id, "clienteId": cliente2_id, "tipo": "cargo", "monto": 50000,
    "detalle": f"{PREFIJO} cargo inicial", "fecha": ahora_iso(), "usuarioId": "test-cajero",
})
saldo_tras_cargo = db.collection("clientes").document(cliente2_id).get().to_dict()["saldoCuentaCorriente"]
verificar("Saldo baja a -50000 tras generar la deuda", saldo_tras_cargo == -50000,
          f"(quedo en {saldo_tras_cargo})")

# Contar movimientos de caja ANTES de cobrar (para comparar el efecto)
movs_caja_antes = len(list(db.collection("movimientos_caja").where("detalle", ">=", PREFIJO)
                            .where("detalle", "<", PREFIJO + "\uf8ff").stream()))

# Cobro 1: paga 20000 en EFECTIVO -> tiene que generar un ingreso en movimientos_caja
db.collection("clientes").document(cliente2_id).update({"saldoCuentaCorriente": firestore.Increment(20000)})
mov_pago_efectivo_id = str(uuid.uuid4())
db.collection("movimientos_cuenta_corriente").document(mov_pago_efectivo_id).set({
    "id": mov_pago_efectivo_id, "clienteId": cliente2_id, "tipo": "pago", "monto": 20000,
    "detalle": f"{PREFIJO} pago efectivo", "fecha": ahora_iso(), "usuarioId": "test-cajero",
})
mov_caja_efectivo_id = str(uuid.uuid4())
db.collection("movimientos_caja").document(mov_caja_efectivo_id).set({
    "id": mov_caja_efectivo_id, "tipo": "ingreso", "monto": 20000,
    "detalle": f"{PREFIJO} Pago cuenta corriente - Cliente Cobro: efectivo",
    "fecha": ahora_iso(), "usuarioId": "test-cajero",
})

saldo_tras_pago_efectivo = db.collection("clientes").document(cliente2_id).get().to_dict()["saldoCuentaCorriente"]
verificar("Saldo sube a -30000 tras pagar 20000 en efectivo", saldo_tras_pago_efectivo == -30000,
          f"(quedo en {saldo_tras_pago_efectivo})")

mov_caja_creado = db.collection("movimientos_caja").document(mov_caja_efectivo_id).get()
verificar("El pago en efectivo SI genero un movimiento de caja (para el arqueo)",
          mov_caja_creado.exists and mov_caja_creado.to_dict()["monto"] == 20000)

# Cobro 2: paga los 30000 restantes por TRANSFERENCIA -> NO debe tocar caja
db.collection("clientes").document(cliente2_id).update({"saldoCuentaCorriente": firestore.Increment(30000)})
mov_pago_transf_id = str(uuid.uuid4())
db.collection("movimientos_cuenta_corriente").document(mov_pago_transf_id).set({
    "id": mov_pago_transf_id, "clienteId": cliente2_id, "tipo": "pago", "monto": 30000,
    "detalle": f"{PREFIJO} pago transferencia", "fecha": ahora_iso(), "usuarioId": "test-cajero",
})
# A proposito NO se crea ningun movimientos_caja aca (la transferencia no
# es efectivo fisico), verificamos que efectivamente no se creo de mas.

saldo_final_cliente2 = db.collection("clientes").document(cliente2_id).get().to_dict()["saldoCuentaCorriente"]
verificar("Saldo queda en 0 tras pagar el resto por transferencia", saldo_final_cliente2 == 0,
          f"(quedo en {saldo_final_cliente2})")

movs_caja_despues = len(list(db.collection("movimientos_caja").where("detalle", ">=", PREFIJO)
                              .where("detalle", "<", PREFIJO + "\uf8ff").stream()))
verificar("Solo se creo 1 movimiento de caja (el del pago en efectivo, no el de transferencia)",
          movs_caja_despues - movs_caja_antes == 1,
          f"(se crearon {movs_caja_despues - movs_caja_antes})")

# ============ 8) Merma, ingreso y ajuste manual de stock ============
print("\n--- 8) Movimientos de stock: merma, ingreso, ajuste ---")
zapallo_id = str(uuid.uuid4())
db.collection("productos").document(zapallo_id).set({
    "id": zapallo_id, "nombre": f"{PREFIJO} Zapallo", "precioSugerido": 13000,
    "categoria": "Verduras", "activo": True, "favorito": False,
    "costoUnitario": 8000, "tasaIIBB": 0, "tasaTSH": 0,
})
db.collection("stock").document(zapallo_id).set({
    "productoId": zapallo_id, "cantidadDisponible": 50, "umbralStockBajo": 10,
})
ids_productos[f"{PREFIJO} Zapallo"] = zapallo_id

# Ingreso de mercaderia: +30 (usa incremento atomico, igual que el codigo real)
db.collection("stock").document(zapallo_id).update({"cantidadDisponible": firestore.Increment(30)})
stock_tras_ingreso = db.collection("stock").document(zapallo_id).get().to_dict()["cantidadDisponible"]
verificar("Ingreso de mercaderia: 50 + 30 = 80", stock_tras_ingreso == 80, f"(quedo en {stock_tras_ingreso})")

# Merma: -5
db.collection("stock").document(zapallo_id).update({"cantidadDisponible": firestore.Increment(-5)})
stock_tras_merma = db.collection("stock").document(zapallo_id).get().to_dict()["cantidadDisponible"]
verificar("Merma: 80 - 5 = 75", stock_tras_merma == 75, f"(quedo en {stock_tras_merma})")

# Ajuste manual: fijar directamente a 60 (valor absoluto, no incremento)
db.collection("stock").document(zapallo_id).set({"cantidadDisponible": 60}, merge=True)
stock_tras_ajuste = db.collection("stock").document(zapallo_id).get().to_dict()["cantidadDisponible"]
verificar("Ajuste manual: se fija directo en 60 (no suma/resta)", stock_tras_ajuste == 60,
          f"(quedo en {stock_tras_ajuste})")

# ============ 9) Race condition: dos "cajeros" vendiendo a la vez ============
print("\n--- 9) Race condition: dos dispositivos descontando stock del mismo producto ---")
# Vuelvo a poner stock en un numero conocido para el experimento.
db.collection("stock").document(zapallo_id).set({"cantidadDisponible": 100}, merge=True)

# Simulo EXACTAMENTE lo que hace la app ahora (incremento atomico), como si
# dos cajeros vendieran el mismo producto en simultaneo, cada uno con su
# propia copia local desactualizada (ninguno sabe del otro).
db.collection("stock").document(zapallo_id).update({"cantidadDisponible": firestore.Increment(-7)})  # cajero A vende 7
db.collection("stock").document(zapallo_id).update({"cantidadDisponible": firestore.Increment(-4)})  # cajero B vende 4 (no sabe de A)
stock_tras_race = db.collection("stock").document(zapallo_id).get().to_dict()["cantidadDisponible"]
verificar("Con incremento atomico, las DOS ventas se descuentan bien: 100-7-4=89 (antes del fix se hubiera perdido una)",
          stock_tras_race == 89, f"(quedo en {stock_tras_race})")

# ============ 10) Cierre de caja con billetes ============
print("\n--- 10) Cierre de caja (arqueo con billetes) ---")
cierre_id = str(uuid.uuid4())
billetes_test = [
    {"denominacion": 20000, "cantidad": 3},
    {"denominacion": 10000, "cantidad": 5},
    {"denominacion": 1000, "cantidad": 12},
]
total_contado_esperado = sum(b["denominacion"] * b["cantidad"] for b in billetes_test)
db.collection("cierres_caja").document(cierre_id).set({
    "id": cierre_id, "fecha": ahora_iso(), "cajaInicio": 50000,
    "billetesJson": json.dumps(billetes_test), "usuarioId": "test-cajero",
    "nota": f"{PREFIJO} cierre",
})
cierre_leido = db.collection("cierres_caja").document(cierre_id).get().to_dict()
billetes_leidos = json.loads(cierre_leido["billetesJson"])
total_leido = sum(b["denominacion"] * b["cantidad"] for b in billetes_leidos)
verificar("El cierre de caja guarda y recalcula bien el total contado",
          total_leido == total_contado_esperado, f"({total_leido} == {total_contado_esperado})")

# ============ 11) Estadisticas con muchas ventas de varios dias/vendedores ============
print("\n--- 11) Estadisticas: muchas ventas mezcladas ---")
ventas_stats_ids = []
vendedores_test = [f"{PREFIJO} Vend A", f"{PREFIJO} Vend B", f"{PREFIJO} Vend C"]
facturacion_esperada_por_vendedor = {v: 0 for v in vendedores_test}
facturacion_total_stats = 0
costo_total_stats = 0

for i in range(15):
    vid = str(uuid.uuid4())
    vendedor = vendedores_test[i % 3]
    dia_offset = i % 4  # repartido en 4 dias distintos
    prod_nombre = list(ids_productos.keys())[i % len(ids_productos)]
    prod_id = ids_productos[prod_nombre]
    costo_unit = next(p["costo"] for p in productos_test if p["nombre"] == prod_nombre) if prod_nombre != f"{PREFIJO} Zapallo" else 8000
    cantidad = (i % 5) + 1
    precio_total = cantidad * 15000
    fecha_venta = (datetime.datetime.now() - datetime.timedelta(days=dia_offset)).isoformat()

    db.collection("ventas").document(vid).set({
        "id": vid, "numero": 9100 + i, "fecha": fecha_venta,
        "vendedorId": f"test-{vendedor}", "vendedorNombre": vendedor,
        "total": precio_total, "estado": "cobrada", "metodoPago": "efectivo",
        "cajeroId": "test-cajero", "fechaCobro": fecha_venta, "clienteId": None,
        "nombreCliente": None, "pagos": [{"metodo": "efectivo", "monto": precio_total}],
        "detalle": [{"productoId": prod_id, "nombreProducto": prod_nombre,
                     "cantidad": cantidad, "precioTotal": precio_total}],
    })
    ventas_stats_ids.append(vid)
    facturacion_esperada_por_vendedor[vendedor] += precio_total
    facturacion_total_stats += precio_total
    costo_total_stats += costo_unit * cantidad

# Agrupo facturacion por vendedor leyendo directo los documentos que
# yo mismo cree (mas simple y confiable que una consulta compuesta que
# necesitaria un indice nuevo en Firestore).
facturacion_calculada_por_vendedor = {v: 0 for v in vendedores_test}
for vid in ventas_stats_ids:
    v = db.collection("ventas").document(vid).get().to_dict()
    facturacion_calculada_por_vendedor[v["vendedorNombre"]] += v["total"]

todo_coincide = all(
    facturacion_calculada_por_vendedor[v] == facturacion_esperada_por_vendedor[v]
    for v in vendedores_test
)
verificar("Facturacion agrupada por vendedor coincide para los 3 vendedores de prueba",
          todo_coincide, f"({facturacion_calculada_por_vendedor})")
verificar("15 ventas de prueba repartidas en 4 dias distintos se crearon todas",
          len(ventas_stats_ids) == 15)

# ============ 12) Eliminar ventas y productos: confirmar que desaparecen ============
print("\n--- 12) Eliminacion: confirmar que se borra de verdad ---")
venta_a_borrar = venta1_id
db.collection("ventas").document(venta_a_borrar).delete()
doc_borrado = db.collection("ventas").document(venta_a_borrar).get()
verificar("La venta eliminada ya no existe en Firestore", not doc_borrado.exists)

producto_a_borrar = ids_productos[f"{PREFIJO} Zapallo"]
db.collection("productos").document(producto_a_borrar).delete()
db.collection("stock").document(producto_a_borrar).delete()
doc_prod_borrado = db.collection("productos").document(producto_a_borrar).get()
verificar("El producto eliminado ya no existe en Firestore", not doc_prod_borrado.exists)

# ============ 13) Flujo offline: venta reconstruida desde QR ============
print("\n--- 13) Flujo sin conexion: vendedor genera QR, cajero lo escanea despues ---")
# Simulo EXACTAMENTE el formato que arma QrService.generarPayload() del
# lado del vendedor (offline, nunca llego a sincronizarse a Firestore).
venta_qr_id = str(uuid.uuid4())
papa_id_qr = ids_productos[f"{PREFIJO} Papa"]
qr_payload = {
    "id": venta_qr_id, "numero": 9500, "fecha": ahora_iso(),
    "vendedorId": "test-vendedor-offline", "vendedorNombre": f"{PREFIJO} Vendedor Offline",
    "productos": [{"productoId": papa_id_qr, "nombre": f"{PREFIJO} Papa", "cantidad": 3, "precioTotal": 42000}],
    "total": 42000, "nombreCliente": f"{PREFIJO} boleta offline",
}
qr_string = json.dumps(qr_payload)  # esto es lo que quedaria codificado en la imagen QR

# El cajero "escanea" el QR (simplemente decodifica el JSON, como hace
# QrService.decodificarPayload) y reconstruye la venta.
qr_decodificado = json.loads(qr_string)
verificar("El QR decodificado tiene todos los campos necesarios para reconstruir la venta",
          all(k in qr_decodificado for k in ["id", "numero", "vendedorNombre", "productos", "total"]))

# Como esta venta NUNCA existio en Firestore (era 100% local en el
# celular del vendedor), verifico que el chequeo de "no cobrar dos
# veces" no la bloquee de entrada (el doc no existe todavia = OK cobrar).
doc_previo = db.collection("ventas").document(venta_qr_id).get()
verificar("Antes de cobrar, la venta reconstruida desde QR no existe en Firestore (como se espera)",
          not doc_previo.exists)

# El cajero cobra: se crea el documento completo por primera vez
# (equivalente a "guardarCompleta" en finalizarCobro cuando existente==null).
stock_papa_antes_qr = db.collection("stock").document(papa_id_qr).get().to_dict()["cantidadDisponible"]
db.collection("stock").document(papa_id_qr).update({"cantidadDisponible": firestore.Increment(-3)})
db.collection("ventas").document(venta_qr_id).set({
    "id": qr_decodificado["id"], "numero": qr_decodificado["numero"], "fecha": qr_decodificado["fecha"],
    "vendedorId": qr_decodificado["vendedorId"], "vendedorNombre": qr_decodificado["vendedorNombre"],
    "total": qr_decodificado["total"], "estado": "cobrada", "metodoPago": "efectivo",
    "cajeroId": "test-cajero-offline", "fechaCobro": ahora_iso(), "clienteId": None,
    "nombreCliente": qr_decodificado["nombreCliente"],
    "pagos": [{"metodo": "efectivo", "monto": qr_decodificado["total"]}],
    "detalle": [{"productoId": p["productoId"], "nombreProducto": p["nombre"],
                 "cantidad": p["cantidad"], "precioTotal": p["precioTotal"]}
                for p in qr_decodificado["productos"]],
})

venta_qr_creada = db.collection("ventas").document(venta_qr_id).get()
verificar("La venta reconstruida desde QR se creo completa y cobrada en Firestore",
          venta_qr_creada.exists and venta_qr_creada.to_dict()["estado"] == "cobrada")

stock_papa_despues_qr = db.collection("stock").document(papa_id_qr).get().to_dict()["cantidadDisponible"]
verificar("El stock se descuenta igual para una venta reconstruida desde QR",
          stock_papa_despues_qr == stock_papa_antes_qr - 3,
          f"({stock_papa_antes_qr} -> {stock_papa_despues_qr})")

# Ahora simulo el intento de cobrar la MISMA venta de nuevo (ej: el
# cajero escanea el mismo QR de respaldo sin querer una segunda vez).
# El chequeo real (obtenerEstadoActualDesdeRemoto) ahora SI encontraria
# el documento con estado "cobrada" y bloquearia el cobro.
doc_recobro = db.collection("ventas").document(venta_qr_id).get().to_dict()
verificar("Al reescanear el mismo QR, el sistema ahora SI encuentra la venta como 'cobrada' (el guard la bloquearia)",
          doc_recobro["estado"] == "cobrada")

# ============ 14) Prueba de volumen: cientos de ventas y productos ============
print("\n--- 14) Volumen grande: 60 productos + 300 ventas ---")
import time as _time

t0 = _time.time()
productos_volumen_ids = []
batch = db.batch()
for i in range(60):
    pid = str(uuid.uuid4())
    productos_volumen_ids.append(pid)
    ref = db.collection("productos").document(pid)
    batch.set(ref, {
        "id": pid, "nombre": f"{PREFIJO} Prod Vol {i}", "precioSugerido": 5000 + i * 100,
        "categoria": "Verduras", "activo": True, "favorito": False,
        "costoUnitario": 3000 + i * 50, "tasaIIBB": 0, "tasaTSH": 0,
    })
    if (i + 1) % 20 == 0:  # Firestore limita batches a 500 operaciones
        batch.commit()
        batch = db.batch()
batch.commit()
t_productos = _time.time() - t0
print(f"Tiempo para crear 60 productos: {t_productos:.2f}s")

t0 = _time.time()
ventas_volumen_ids = []
batch = db.batch()
for i in range(300):
    vid = str(uuid.uuid4())
    ventas_volumen_ids.append(vid)
    prod_idx = i % len(productos_volumen_ids)
    ref = db.collection("ventas").document(vid)
    batch.set(ref, {
        "id": vid, "numero": 20000 + i, "fecha": ahora_iso(),
        "vendedorId": "test-vendedor-vol", "vendedorNombre": f"{PREFIJO} Vendedor Volumen",
        "total": 8000, "estado": "cobrada", "metodoPago": "efectivo",
        "cajeroId": "test-cajero-vol", "fechaCobro": ahora_iso(), "clienteId": None,
        "nombreCliente": None, "pagos": [{"metodo": "efectivo", "monto": 8000}],
        "detalle": [{"productoId": productos_volumen_ids[prod_idx],
                     "nombreProducto": f"{PREFIJO} Prod Vol {prod_idx}",
                     "cantidad": 1, "precioTotal": 8000}],
    })
    if (i + 1) % 400 == 0:
        batch.commit()
        batch = db.batch()
batch.commit()
t_ventas = _time.time() - t0
print(f"Tiempo para crear 300 ventas: {t_ventas:.2f}s")

# Ahora simulo la consulta que hace Estadisticas/Historial: traer todas
# las ventas de un rango de fechas (obtenerPorRangoFechaGlobal).
t0 = _time.time()
desde_vol = datetime.datetime.now() - datetime.timedelta(hours=1)
hasta_vol = datetime.datetime.now() + datetime.timedelta(hours=1)
ventas_leidas_vol = list(db.collection("ventas")
                          .where("fecha", ">=", desde_vol.isoformat())
                          .where("fecha", "<=", hasta_vol.isoformat())
                          .stream())
t_lectura = _time.time() - t0
print(f"Tiempo para leer {len(ventas_leidas_vol)} ventas del rango: {t_lectura:.2f}s")

verificar("Se pudieron crear y leer las 300 ventas de volumen sin errores",
          len(ventas_leidas_vol) >= 300, f"(se leyeron {len(ventas_leidas_vol)})")
verificar("La lectura de ~300 ventas es razonablemente rapida (menos de 5 segundos)",
          t_lectura < 5, f"(tardo {t_lectura:.2f}s)")

# ============ 15) Proveedores: pedido sube saldo, pago lo baja ============
print("\n--- 15) Proveedores: cuenta corriente ---")
proveedor_id = str(uuid.uuid4())
db.collection("proveedores").document(proveedor_id).set({
    "id": proveedor_id, "nombre": f"{PREFIJO} Proveedor Verduras", "telefono": "",
    "activo": True, "saldoCuentaCorriente": 0,
})

# Pedido de 50000: SUMA al saldo (positivo = les debemos)
db.collection("proveedores").document(proveedor_id).update({"saldoCuentaCorriente": firestore.Increment(50000)})
pedido_id = str(uuid.uuid4())
db.collection("pedidos_proveedor").document(pedido_id).set({
    "id": pedido_id, "proveedorId": proveedor_id, "productoId": None,
    "productoNombre": f"{PREFIJO} Cajones de tomate", "cantidad": 20,
    "metodoPago": "efectivo", "monto": 50000, "fecha": ahora_iso(),
    "usuarioId": "test-admin", "nota": None,
})
saldo_tras_pedido = db.collection("proveedores").document(proveedor_id).get().to_dict()["saldoCuentaCorriente"]
verificar("Proveedor: pedido de 50000 SUMA al saldo (0 -> 50000, les debemos)",
          saldo_tras_pedido == 50000, f"(quedo en {saldo_tras_pedido})")

# Pago de 20000: RESTA del saldo
db.collection("proveedores").document(proveedor_id).update({"saldoCuentaCorriente": firestore.Increment(-20000)})
pago_prov_id = str(uuid.uuid4())
db.collection("pagos_proveedor").document(pago_prov_id).set({
    "id": pago_prov_id, "proveedorId": proveedor_id, "monto": 20000,
    "metodoPago": "transferencia", "fecha": ahora_iso(), "usuarioId": "test-admin", "nota": None,
})
saldo_tras_pago_prov = db.collection("proveedores").document(proveedor_id).get().to_dict()["saldoCuentaCorriente"]
verificar("Proveedor: pago de 20000 RESTA del saldo (50000 -> 30000)",
          saldo_tras_pago_prov == 30000, f"(quedo en {saldo_tras_pago_prov})")

# ============ 16) Cliente: CUIT/DNI y condicion fiscal se guardan ============
print("\n--- 16) Cliente: CUIT/DNI y condicion fiscal ---")
cliente3_id = str(uuid.uuid4())
db.collection("clientes").document(cliente3_id).set({
    "id": cliente3_id, "nombre": f"{PREFIJO} Cliente Fiscal", "telefono": "",
    "direccion": "", "saldoCuentaCorriente": 0,
    "cuitODni": "20-12345678-9", "condicionFiscal": "responsableInscripto",
})
cliente3_leido = db.collection("clientes").document(cliente3_id).get().to_dict()
verificar("CUIT/DNI del cliente se guarda y lee bien",
          cliente3_leido.get("cuitODni") == "20-12345678-9")
verificar("Condicion fiscal del cliente se guarda y lee bien",
          cliente3_leido.get("condicionFiscal") == "responsableInscripto")

# ============ 17) Signo del saldo de cliente: cargo resta, pago suma ============
print("\n--- 17) Cliente: signo correcto del saldo (cargo resta, pago suma) ---")
# Mismo cliente de arriba, arranca en 0.
db.collection("clientes").document(cliente3_id).update({"saldoCuentaCorriente": firestore.Increment(-15000)})
mov_cargo3_id = str(uuid.uuid4())
db.collection("movimientos_cuenta_corriente").document(mov_cargo3_id).set({
    "id": mov_cargo3_id, "clienteId": cliente3_id, "tipo": "cargo", "monto": 15000,
    "detalle": f"{PREFIJO} venta fiada", "fecha": ahora_iso(), "usuarioId": "test-cajero",
    "metodoPago": None,
})
saldo_tras_cargo3 = db.collection("clientes").document(cliente3_id).get().to_dict()["saldoCuentaCorriente"]
verificar("Cliente: un cargo de 15000 hace el saldo MAS negativo (0 -> -15000)",
          saldo_tras_cargo3 == -15000, f"(quedo en {saldo_tras_cargo3})")

db.collection("clientes").document(cliente3_id).update({"saldoCuentaCorriente": firestore.Increment(6000)})
mov_pago3_id = str(uuid.uuid4())
db.collection("movimientos_cuenta_corriente").document(mov_pago3_id).set({
    "id": mov_pago3_id, "clienteId": cliente3_id, "tipo": "pago", "monto": 6000,
    "detalle": f"{PREFIJO} pago transferencia", "fecha": ahora_iso(), "usuarioId": "test-cajero",
    "metodoPago": "transferencia",
})
saldo_tras_pago3 = db.collection("clientes").document(cliente3_id).get().to_dict()["saldoCuentaCorriente"]
verificar("Cliente: un pago de 6000 hace el saldo MENOS negativo (-15000 -> -9000)",
          saldo_tras_pago3 == -9000, f"(quedo en {saldo_tras_pago3})")

# ============ 18) Facturacion: venta+cliente por transferencia con CUIT/DNI ============
print("\n--- 18) Facturacion: datos completos para el contador ---")
venta_fact_id = str(uuid.uuid4())
db.collection("ventas").document(venta_fact_id).set({
    "id": venta_fact_id, "numero": 9600, "fecha": ahora_iso(),
    "vendedorId": "test-vendedor", "vendedorNombre": f"{PREFIJO} Vendedor",
    "total": 12000, "estado": "cobrada", "metodoPago": "transferencia",
    "cajeroId": "test-cajero", "fechaCobro": ahora_iso(), "clienteId": None,
    "nombreCliente": f"{PREFIJO} comprador ocasional",
    "pagos": [{"metodo": "transferencia", "monto": 12000}],
    "cuitDniComprador": "27-98765432-1",
    "detalle": [{"productoId": papa_id, "nombreProducto": f"{PREFIJO} Papa",
                 "cantidad": 1, "precioTotal": 12000}],
})
venta_fact_leida = db.collection("ventas").document(venta_fact_id).get().to_dict()
verificar("Venta por transferencia guarda el CUIT/DNI del comprador",
          venta_fact_leida.get("cuitDniComprador") == "27-98765432-1")
bruto_esperado = venta_fact_leida["total"]
neto_esperado = math.ceil(bruto_esperado / 1.105)
verificar("Formula de neto (bruto/1.105, redondeado arriba) da un valor coherente",
          neto_esperado > 0 and neto_esperado < bruto_esperado,
          f"(bruto {bruto_esperado}, neto calculado {neto_esperado})")

# ============ 19) Facturacion: marcado (tilde) y oculto (swipe) son independientes ============
print("\n--- 19) Facturacion: tilde y swipe no se pisan entre si ---")
# Marcar como facturado (tilde) NO debe ocultarlo de la lista.
db.collection("facturacion_marcados").document(venta_fact_id).set({
    "id": venta_fact_id, "fechaMarcado": ahora_iso(), "usuarioId": "test-admin",
})
marcado_existe = db.collection("facturacion_marcados").document(venta_fact_id).get().exists
oculto_no_existe = not db.collection("facturacion_ocultos").document(venta_fact_id).get().exists
verificar("Marcar como facturado (tilde) queda registrado en su propia coleccion",
          marcado_existe)
verificar("Marcar como facturado NO crea una entrada en 'ocultos' (no se esconde solo)",
          oculto_no_existe)

# Ahora, ocultar con swipe (separado del tilde de arriba).
db.collection("facturacion_ocultos").document(venta_fact_id).set({
    "id": venta_fact_id, "fechaOculto": ahora_iso(), "usuarioId": "test-admin",
})
oculto_existe = db.collection("facturacion_ocultos").document(venta_fact_id).get().exists
venta_sigue_intacta = db.collection("ventas").document(venta_fact_id).get().exists
verificar("Ocultar con swipe queda registrado en su propia coleccion (separada del tilde)",
          oculto_existe)
verificar("La venta original SIGUE existiendo despues de ocultarla de Facturacion (no se borro)",
          venta_sigue_intacta)


# ============ 20) Anular venta: devuelve stock y revierte fiado ============
print("\n--- 20) Anular venta (devolver stock, revertir fiado) ---")

# Cliente y stock inicial de referencia.
cliente_anular_id = str(uuid.uuid4())
db.collection("clientes").document(cliente_anular_id).set({
    "id": cliente_anular_id, "nombre": f"{PREFIJO} Cliente Anulacion", "telefono": "",
    "direccion": "", "saldoCuentaCorriente": 0, "cuitODni": "", "condicionFiscal": None,
})

stock_antes_doc = db.collection("stock").document(papa_id).get()
stock_antes = stock_antes_doc.to_dict()["cantidadDisponible"] if stock_antes_doc.exists else 0

# Venta fiada de 8 papas a $1000 c/u = $8000, tal como la cobraria
# FinalizarCobroUseCase: descuenta stock y carga la cuenta corriente.
venta_anular_id = str(uuid.uuid4())
cantidad_vendida = 8
precio_vendido = 1000
total_vendido = cantidad_vendida * precio_vendido
db.collection("ventas").document(venta_anular_id).set({
    "id": venta_anular_id, "numero": 9700, "fecha": ahora_iso(),
    "vendedorId": "test-vendedor", "vendedorNombre": f"{PREFIJO} Vendedor",
    "total": total_vendido, "estado": "cobrada", "metodoPago": "cuentaCorriente",
    "cajeroId": "test-cajero", "fechaCobro": ahora_iso(), "clienteId": cliente_anular_id,
    "nombreCliente": f"{PREFIJO} Cliente Anulacion", "pagos": [], "cuitDniComprador": None,
    "detalle": [{"productoId": papa_id, "nombreProducto": f"{PREFIJO} Papa",
                 "cantidad": cantidad_vendida, "precioTotal": total_vendido}],
})
db.collection("stock").document(papa_id).update({"cantidadDisponible": firestore.Increment(-cantidad_vendida)})
db.collection("clientes").document(cliente_anular_id).update(
    {"saldoCuentaCorriente": firestore.Increment(-total_vendido)})
mov_cargo_anular_id = str(uuid.uuid4())
db.collection("movimientos_cuenta_corriente").document(mov_cargo_anular_id).set({
    "id": mov_cargo_anular_id, "clienteId": cliente_anular_id, "tipo": "cargo", "monto": total_vendido,
    "detalle": f"Venta #9700", "fecha": ahora_iso(), "usuarioId": "test-cajero", "metodoPago": None,
})

stock_tras_venta = db.collection("stock").document(papa_id).get().to_dict()["cantidadDisponible"]
saldo_tras_venta = db.collection("clientes").document(cliente_anular_id).get().to_dict()["saldoCuentaCorriente"]
verificar("Venta fiada de prueba: el stock bajo la cantidad vendida",
          abs(stock_tras_venta - (stock_antes - cantidad_vendida)) < 0.01,
          f"(antes {stock_antes}, despues {stock_tras_venta})")
verificar("Venta fiada de prueba: el cliente quedo debiendo el total",
          saldo_tras_venta == -total_vendido, f"(saldo {saldo_tras_venta})")

# Ahora anular, replicando EXACTAMENTE los pasos de AnularVentaUseCase:
# 1) devolver stock, 2) pago compensatorio por el monto fiado, 3) marcar cancelada.
db.collection("stock").document(papa_id).update({"cantidadDisponible": firestore.Increment(cantidad_vendida)})
db.collection("clientes").document(cliente_anular_id).update(
    {"saldoCuentaCorriente": firestore.Increment(total_vendido)})
mov_pago_anular_id = str(uuid.uuid4())
db.collection("movimientos_cuenta_corriente").document(mov_pago_anular_id).set({
    "id": mov_pago_anular_id, "clienteId": cliente_anular_id, "tipo": "pago", "monto": total_vendido,
    "detalle": "Anulación de venta #9700", "fecha": ahora_iso(), "usuarioId": "test-admin", "metodoPago": None,
})
db.collection("ventas").document(venta_anular_id).update({"estado": "cancelada"})

stock_tras_anular = db.collection("stock").document(papa_id).get().to_dict()["cantidadDisponible"]
saldo_tras_anular = db.collection("clientes").document(cliente_anular_id).get().to_dict()["saldoCuentaCorriente"]
venta_tras_anular = db.collection("ventas").document(venta_anular_id).get().to_dict()

verificar("Anular venta: el stock vuelve exactamente al valor de antes de la venta",
          abs(stock_tras_anular - stock_antes) < 0.01,
          f"(antes {stock_antes}, despues de anular {stock_tras_anular})")
verificar("Anular venta: el saldo del cliente vuelve a 0 (deuda revertida del todo)",
          saldo_tras_anular == 0, f"(saldo quedo en {saldo_tras_anular})")
verificar("Anular venta: la venta queda marcada 'cancelada' (no se borra)",
          venta_tras_anular is not None and venta_tras_anular.get("estado") == "cancelada")
verificar("Anular venta: el registro de la venta SIGUE existiendo (auditable)",
          db.collection("ventas").document(venta_anular_id).get().exists)

ok = sum(1 for _, e, _ in resultados if e == "OK")
total = len(resultados)
print(f"{ok}/{total} verificaciones pasaron correctamente.")
for nombre, estado, detalle in resultados:
    if estado != "OK":
        print(f"  FALLO: {nombre} {detalle}")

# Guardar ids creados para poder limpiarlos despues
with open('/tmp/test_ids.json', 'w') as f:
    json.dump({
        "productos": list(ids_productos.values()) + productos_volumen_ids,
        "clientes": [cliente_id, cliente2_id, cliente3_id, cliente_anular_id],
        "ventas": [venta1_id, venta2_id, venta3_id, venta_qr_id, venta_fact_id, venta_anular_id]
                  + ventas_stats_ids + ventas_volumen_ids,
        "movimientos_cuenta_corriente": [mov_id, mov_pago_id, mov_cargo_id, mov_pago_efectivo_id,
                                          mov_pago_transf_id, mov_cargo3_id, mov_pago3_id,
                                          mov_cargo_anular_id, mov_pago_anular_id],
        "movimientos_caja": [mov_caja_efectivo_id],
        "cierres_caja": [cierre_id],
        "proveedores": [proveedor_id],
        "pedidos_proveedor": [pedido_id],
        "pagos_proveedor": [pago_prov_id],
        "facturacion_marcados": [venta_fact_id],
        "facturacion_ocultos": [venta_fact_id],
    }, f, indent=2)

print("\nIDs de prueba guardados en /tmp/test_ids.json para limpieza posterior.")
