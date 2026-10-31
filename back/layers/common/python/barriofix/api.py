"""Fabrica del resolver de Powertools, comun a todas las Lambdas de API.

Centraliza la validacion con Pydantic, CORS y el mapeo de errores a codigos
HTTP, para que cada funcion solo tenga sus rutas.
"""

from aws_lambda_powertools.event_handler import APIGatewayHttpResolver, CORSConfig
from aws_lambda_powertools.event_handler.exceptions import ServiceError

from barriofix.errores import ConflictoError


def crear_app(cors: bool = True) -> APIGatewayHttpResolver:
    cors_config = CORSConfig(allow_origin="*", allow_headers=["authorization", "content-type"]) if cors else None
    app = APIGatewayHttpResolver(enable_validation=True, cors=cors_config)

    @app.exception_handler(ConflictoError)
    def _conflicto(ex: ConflictoError):
        # Lo lanzan las escrituras condicionales cuando otro gano la carrera
        raise ServiceError(409, str(ex) or "Conflicto con el estado actual del recurso")

    return app
