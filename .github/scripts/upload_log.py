"""Sube el log de un build fallido a la rama ci-logs del propio repo,
usando la Contents API de GitHub (accesible sin pasar por el almacenamiento
de logs de Actions, que tiene restricciones de red distintas).

Uso: python3 upload_log.py <nombre-archivo-en-repo> <ruta-log-local>
Variables de entorno requeridas: GH_TOKEN, GITHUB_REPOSITORY
"""
import base64
import json
import os
import sys
import urllib.request


def main():
    if len(sys.argv) != 3:
        print("Uso: upload_log.py <nombre-archivo-en-repo> <ruta-log-local>")
        sys.exit(1)

    target_name, log_path = sys.argv[1], sys.argv[2]
    token = os.environ["GH_TOKEN"]
    repo = os.environ["GITHUB_REPOSITORY"]

    with open(log_path, "rb") as f:
        content = f.read()
    content = content[-90000:]  # últimos ~90kb alcanzan para ver el error
    b64 = base64.b64encode(content).decode()

    url = f"https://api.github.com/repos/{repo}/contents/{target_name}"
    headers = {"Authorization": f"token {token}", "Accept": "application/vnd.github+json"}

    sha = None
    try:
        req = urllib.request.Request(url + "?ref=ci-logs", headers=headers)
        with urllib.request.urlopen(req) as resp:
            sha = json.load(resp)["sha"]
    except Exception:
        pass

    payload = {
        "message": f"ci: log de error ({target_name})",
        "content": b64,
        "branch": "ci-logs",
    }
    if sha:
        payload["sha"] = sha

    req2 = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        method="PUT",
        headers={**headers, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req2) as resp:
        print("Log guardado, status:", resp.status)


if __name__ == "__main__":
    main()
