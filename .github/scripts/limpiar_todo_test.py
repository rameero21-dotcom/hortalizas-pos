"""Limpieza a fondo: borra TODO lo que tenga el prefijo "TEST -" en
cualquiera de las colecciones relevantes, sin depender de una lista de
IDs guardada de una corrida puntual (que se iba pisando entre corridas
sucesivas de la prueba de integracion durante la sesion de testing).
"""
from google.cloud import firestore

db = firestore.Client.from_service_account_json('/tmp/sa.json')

PREFIJO = "TEST -"
borrados = 0


def es_de_prueba(valor):
    return isinstance(valor, str) and valor.startswith(PREFIJO)


# ---- Productos: por nombre ----
for doc in db.collection("productos").stream():
    d = doc.to_dict()
    if es_de_prueba(d.get("nombre", "")):
        db.collection("stock").document(doc.id).delete()  # su stock asociado
        doc.reference.delete()
        borrados += 1

# ---- Clientes: por nombre ----
ids_clientes_test = []
for doc in db.collection("clientes").stream():
    d = doc.to_dict()
    if es_de_prueba(d.get("nombre", "")):
        ids_clientes_test.append(doc.id)
        doc.reference.delete()
        borrados += 1

# ---- Ventas: por nombreCliente, vendedorNombre, o cajeroId/vendedorId de prueba ----
for doc in db.collection("ventas").stream():
    d = doc.to_dict()
    if (es_de_prueba(d.get("nombreCliente") or "")
            or es_de_prueba(d.get("vendedorNombre") or "")
            or str(d.get("vendedorId", "")).startswith("test-")
            or str(d.get("cajeroId", "")).startswith("test-")):
        doc.reference.delete()
        borrados += 1

# ---- Movimientos de cuenta corriente: por clienteId de prueba o detalle ----
for doc in db.collection("movimientos_cuenta_corriente").stream():
    d = doc.to_dict()
    if d.get("clienteId") in ids_clientes_test or es_de_prueba(d.get("detalle", "")):
        doc.reference.delete()
        borrados += 1

# ---- Movimientos de caja: por detalle ----
for doc in db.collection("movimientos_caja").stream():
    d = doc.to_dict()
    if es_de_prueba(d.get("detalle", "")) or "test-cajero" in str(d.get("usuarioId", "")):
        doc.reference.delete()
        borrados += 1

# ---- Cierres de caja: por nota o usuarioId de prueba ----
for doc in db.collection("cierres_caja").stream():
    d = doc.to_dict()
    if es_de_prueba(d.get("nota") or "") or "test-" in str(d.get("usuarioId", "")):
        doc.reference.delete()
        borrados += 1

# ---- Stock huerfano: cualquier stock cuyo producto ya no existe ----
ids_productos_existentes = {doc.id for doc in db.collection("productos").stream()}
for doc in db.collection("stock").stream():
    if doc.id not in ids_productos_existentes:
        doc.reference.delete()
        borrados += 1

print(f"Limpieza a fondo completa: {borrados} documentos de prueba borrados.")
