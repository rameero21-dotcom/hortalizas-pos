"""Verifica que el secreto FIREBASE_SERVICE_ACCOUNT_JSON tenga el formato
correcto de una clave de servicio, sin imprimir nunca el contenido
sensible (private_key).
"""
import json
import sys

with open('/tmp/sa.json') as f:
    data = json.load(f)

campos_esperados = ['type', 'project_id', 'private_key', 'client_email']
faltantes = [c for c in campos_esperados if c not in data]
if faltantes:
    print('El JSON no tiene los campos esperados:', faltantes)
    sys.exit(1)

print('JSON con formato correcto.')
print('project_id:', data['project_id'])
print('client_email:', data['client_email'])
