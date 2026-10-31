"""Lecturas publicas de categorias, zonas y urgencias.

El ABM lo gestiona Terraform via seed. Al ser el endpoint mas simple sirve para
validar toda la cadena (layer, deploy, ruta, cache).
"""

from aws_lambda_powertools import Logger

from barriofix import catalogos
from barriofix.api import crear_app

logger = Logger(service="catalogos")
app = crear_app()


@app.get("/api/categorias")
def listar_categorias():
    return catalogos.listar("CATEGORIA", _solo_activos())


@app.get("/api/zonas")
def listar_zonas():
    return catalogos.listar("ZONA", _solo_activos())


@app.get("/api/urgencias")
def listar_urgencias():
    return catalogos.listar("URGENCIA", _solo_activos())


def _solo_activos() -> bool:
    # ?activo=false trae todos, por defecto solo los activos
    return app.current_event.get_query_string_value("activo", "true") != "false"


@logger.inject_lambda_context
def handler(event, context):
    return app.resolve(event, context)
