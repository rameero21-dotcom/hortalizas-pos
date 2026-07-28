"""Prueba una conexion real contra Firestore usando la clave de servicio,
haciendo solo una lectura minima y segura: lista los NOMBRES de las
colecciones existentes, sin leer ningun documento ni dato real.
"""
from google.cloud import firestore

db = firestore.Client.from_service_account_json('/tmp/sa.json')
colecciones = [c.id for c in db.collections()]
print('Conexion exitosa. Colecciones encontradas:', colecciones)
