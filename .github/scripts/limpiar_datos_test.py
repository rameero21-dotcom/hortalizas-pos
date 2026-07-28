"""Borra todos los datos de prueba creados por test_integracion_firebase.py.
Los IDs se guardaron en la rama ci-logs del repo (test-ids.json), ya que
la limpieza corre en una maquina distinta a la que genero los datos.
"""
import base64
import json
import os
import urllib.request
from google.cloud import firestore

token = os.environ["GH_TOKEN"]
repo = os.environ["GITHUB_REPOSITORY"]
headers = {"Authorization": f"token {token}", "Accept": "application/vnd.github+json"}

url = f"https://api.github.com/repos/{repo}/contents/test-ids.json?ref=ci-logs"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    data = json.load(resp)
ids = json.loads(base64.b64decode(data["content"]).decode())

db = firestore.Client.from_service_account_json('/tmp/sa.json')

borrados = 0
for coleccion, lista_ids in ids.items():
    for doc_id in lista_ids:
        db.collection(coleccion).document(doc_id).delete()
        borrados += 1

# El stock de los productos de prueba tambien queda con id = productoId
for pid in ids.get("productos", []):
    db.collection("stock").document(pid).delete()
    borrados += 1

print(f"Limpieza completa: {borrados} documentos de prueba borrados.")
