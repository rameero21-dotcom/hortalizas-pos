"""Agrega los permisos de Bluetooth (necesarios en Android 12+) al
AndroidManifest.xml recién generado por "flutter create". Se necesita
correr esto en cada build porque "flutter create" regenera el archivo
desde cero cada vez, así que cualquier permiso agregado a mano en el
repo se perdería.
"""
import re

ARCHIVO = "android/app/src/main/AndroidManifest.xml"

PERMISOS = """    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
"""

with open(ARCHIVO) as f:
    contenido = f.read()

contenido_nuevo = re.sub(r"(<manifest[^>]*>)", r"\1\n" + PERMISOS, contenido, count=1)

with open(ARCHIVO, "w") as f:
    f.write(contenido_nuevo)

print("Permisos de Bluetooth agregados al manifest.")
print("--- Verificación ---")
for linea in contenido_nuevo.splitlines():
    if "BLUETOOTH" in linea:
        print(linea)
