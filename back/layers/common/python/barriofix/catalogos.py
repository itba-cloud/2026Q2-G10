"""Catalogos (categorias, zonas, urgencias) con cache en memoria.

Son pocas decenas de items que casi no cambian. Se leen enteros de la particion
CATALOGO y se cachean mientras la instancia esta caliente, con un TTL corto para
que una edicion se refleje sin reciclar la Lambda.
"""

import time
from typing import Optional

from barriofix import config, dynamo

_cache: dict[str, tuple[float, list[dict]]] = {}

# Como se llama el id en la respuesta de cada tipo (contrato del front)
_CAMPO_ID = {
    "CATEGORIA": "id_categoria",
    "ZONA": "id_zona",
    "URGENCIA": "id_urgencia",
}


def listar(tipo: str, solo_activos: bool = True) -> list[dict]:
    """tipo en {CATEGORIA, ZONA, URGENCIA}. Devuelve la forma que espera el front."""
    items = _leer(tipo)
    if solo_activos:
        items = [i for i in items if i.get("activo", True)]
    salida = [_serializar(tipo, i) for i in items]

    if tipo == "URGENCIA":
        salida.sort(key=lambda x: x.get("orden_prioridad", 0))
    else:
        salida.sort(key=lambda x: x["nombre"])
    return salida


def existe_activo(tipo: str, id_valor: int) -> Optional[dict]:
    for i in _leer(tipo):
        if int(i["id"]) == id_valor and i.get("activo", True):
            return i
    return None


def por_id(tipo: str, id_valor: int) -> Optional[dict]:
    """El catalogo serializado (forma del front) por id, o None."""
    for i in _leer(tipo):
        if int(i["id"]) == id_valor:
            return _serializar(tipo, i)
    return None


def _leer(tipo: str) -> list[dict]:
    ahora = time.time()
    guardado = _cache.get(tipo)
    if guardado and ahora - guardado[0] < config.CATALOGOS_TTL:
        return guardado[1]

    items = dynamo.query_collection("CATALOGO", f"{tipo}#")
    _cache[tipo] = (ahora, items)
    return items


def _serializar(tipo: str, item: dict) -> dict:
    salida = {
        _CAMPO_ID[tipo]: int(item["id"]),
        "nombre": item["nombre"],
        "descripcion": item.get("descripcion") or None,
        "activo": bool(item.get("activo", True)),
    }
    if tipo == "URGENCIA":
        salida["orden_prioridad"] = int(item.get("orden_prioridad", 0))
    return salida
