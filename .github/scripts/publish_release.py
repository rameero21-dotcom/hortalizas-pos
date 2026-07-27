"""Publica (o actualiza) una release de GitHub con un archivo adjunto,
para tener un link de descarga estable y simple, sin depender de la
seccion "Artifacts" de Actions (que a veces no muestra el boton de
descarga correctamente en algunos navegadores).

Uso: python3 publish_release.py <tag> <ruta-archivo-local> <nombre-asset>
Variables de entorno requeridas: GH_TOKEN, GITHUB_REPOSITORY
"""
import json
import mimetypes
import os
import sys
import urllib.request
import urllib.error


def main():
    if len(sys.argv) != 4:
        print("Uso: publish_release.py <tag> <ruta-archivo-local> <nombre-asset>")
        sys.exit(1)

    tag, ruta_local, nombre_asset = sys.argv[1], sys.argv[2], sys.argv[3]
    token = os.environ["GH_TOKEN"]
    repo = os.environ["GITHUB_REPOSITORY"]
    headers = {"Authorization": f"token {token}", "Accept": "application/vnd.github+json"}

    base_url = f"https://api.github.com/repos/{repo}/releases"

    # 1) Buscar si ya existe una release con ese tag.
    release = None
    try:
        req = urllib.request.Request(f"{base_url}/tags/{tag}", headers=headers)
        with urllib.request.urlopen(req) as resp:
            release = json.load(resp)
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise

    # 2) Si no existe, crearla. Si otro job (corren en paralelo) la crea
    # justo en el medio, GitHub devuelve un error de "ya existe" (422);
    # en ese caso simplemente la volvemos a buscar y seguimos con esa.
    if release is None:
        payload = {
            "tag_name": tag,
            "name": tag,
            "body": "Ultima compilacion automatica (se actualiza con cada cambio en main).",
            "prerelease": True,
        }
        req = urllib.request.Request(
            base_url, data=json.dumps(payload).encode(), method="POST",
            headers={**headers, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req) as resp:
                release = json.load(resp)
            print(f"Release '{tag}' creada.")
        except urllib.error.HTTPError as e:
            if e.code == 422:
                print(f"Release '{tag}' ya la creo otro job en paralelo, la reutilizo.")
                req2 = urllib.request.Request(f"{base_url}/tags/{tag}", headers=headers)
                with urllib.request.urlopen(req2) as resp:
                    release = json.load(resp)
            else:
                raise
    else:
        print(f"Release '{tag}' ya existia, reutilizando.")

    release_id = release["id"]
    upload_url = release["upload_url"].split("{")[0]  # viene con un template {?name,label}

    # 3) Si ya hay un asset con el mismo nombre, borrarlo (para poder subir el nuevo).
    assets_req = urllib.request.Request(f"{base_url}/{release_id}/assets", headers=headers)
    with urllib.request.urlopen(assets_req) as resp:
        assets = json.load(resp)
    for a in assets:
        if a["name"] == nombre_asset:
            del_req = urllib.request.Request(
                f"https://api.github.com/repos/{repo}/releases/assets/{a['id']}",
                method="DELETE", headers=headers,
            )
            urllib.request.urlopen(del_req)
            print(f"Asset anterior '{nombre_asset}' borrado.")

    # 4) Subir el archivo nuevo.
    content_type = mimetypes.guess_type(nombre_asset)[0] or "application/octet-stream"
    with open(ruta_local, "rb") as f:
        contenido = f.read()

    upload_req = urllib.request.Request(
        f"{upload_url}?name={nombre_asset}",
        data=contenido,
        method="POST",
        headers={**headers, "Content-Type": content_type},
    )
    with urllib.request.urlopen(upload_req) as resp:
        resultado = json.load(resp)
    print(f"Asset '{nombre_asset}' subido. URL de descarga: {resultado['browser_download_url']}")


if __name__ == "__main__":
    main()
