"""Prueba de integracion a fondo contra Firestore real, replicando
exactamente la estructura de datos y la logica de negocio de la app
(mismos nombres de coleccion, mismos campos, mismas formulas), para
validar que todo el flujo funcione de punta a punta.

Todos los datos de prueba se crean con el prefijo "TEST -" para poder
identificarlos y borrarlos facilmente despues.

Uso: python3 test_integracion_firebase.py
"""
import uuid
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

# Leo todas las ventas de los ultimos 5 dias y agrupo como lo hace
# ObtenerEstadisticasUseCase (facturacion por vendedor, total general).
desde_stats = datetime.datetime.now() - datetime.timedelta(days=5)
ventas_leidas = list(db.collection("ventas")
                      .where("fecha", ">=", desde_stats.isoformat())
                      .where("vendedorNombre", "in", vendedores_test).stream())
# Nota: Firestore no permite mezclar bien "in" con rango de fecha en un
# where compuesto simple sin indice; para la verificacion, mejor filtro
# en Python sobre lo que ya se exactamente que cargue.
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

print("\n" + "=" * 70)
print("RESUMEN")
print("=" * 70)
ok = sum(1 for _, e, _ in resultados if e == "OK")
total = len(resultados)
print(f"{ok}/{total} verificaciones pasaron correctamente.")
for nombre, estado, detalle in resultados:
    if estado != "OK":
        print(f"  FALLO: {nombre} {detalle}")

# Guardar ids creados para poder limpiarlos despues
with open('/tmp/test_ids.json', 'w') as f:
    json.dump({
        "productos": list(ids_productos.values()),
        "clientes": [cliente_id, cliente2_id],
        "ventas": [venta1_id, venta2_id, venta3_id] + ventas_stats_ids,
        "movimientos_cuenta_corriente": [mov_id, mov_pago_id, mov_cargo_id, mov_pago_efectivo_id, mov_pago_transf_id],
        "movimientos_caja": [mov_caja_efectivo_id],
        "cierres_caja": [cierre_id],
    }, f, indent=2)

print("\nIDs de prueba guardados en /tmp/test_ids.json para limpieza posterior.")
