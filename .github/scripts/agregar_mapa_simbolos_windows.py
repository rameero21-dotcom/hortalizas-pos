"""Agrega la opcion de linker "/MAP" al CMakeLists.txt del runner de
Windows, recien generado por "flutter create". Hay que correr esto en
cada build porque "flutter create" regenera windows/ desde cero cada
vez, asi que cualquier cambio a mano en el repo se perderia.

Por que hace falta: cuando la app se cierra sola en la PC de un
usuario sin ningun aviso, el Visor de eventos de Windows (Application
Error / Id. 1000) da un "modulo con errores" y un "desplazamiento con
errores" (una direccion de memoria relativa al inicio del .exe) - pero
sin un archivo de simbolos que coincida con ESA compilacion exacta, no
hay forma de saber a que funcion corresponde esa direccion.

El archivo .map que genera el linker con "/MAP" es texto plano (se
puede leer sin ninguna herramienta de Windows) y lista el rango de
direcciones de cada funcion, asi que alcanza para buscar ahi la
direccion del crash reportado y encontrar en que funcion pasa.
"""
ARCHIVO = "windows/runner/CMakeLists.txt"

LINEA_A_AGREGAR = (
    '\n# Genera un archivo .map (texto plano) junto al .exe, con el rango\n'
    '# de direcciones de cada funcion - para poder ubicar a que funcion\n'
    '# corresponde el "desplazamiento con errores" que reporta el Visor\n'
    '# de eventos de Windows si la app llega a crashear en alguna PC.\n'
    'target_link_options(${BINARY_NAME} PRIVATE "/MAP")\n'
)

with open(ARCHIVO) as f:
    contenido = f.read()

marca = "add_dependencies(${BINARY_NAME} flutter_assemble)"
if marca not in contenido:
    raise SystemExit(f"No se encontro la linea esperada en {ARCHIVO}; revisar si cambio el template de Flutter.")

contenido_nuevo = contenido.replace(marca, marca + "\n" + LINEA_A_AGREGAR)

with open(ARCHIVO, "w") as f:
    f.write(contenido_nuevo)

print("Opcion /MAP agregada a windows/runner/CMakeLists.txt")
