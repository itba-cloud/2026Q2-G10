"""Usuario autenticado, a partir de los claims que valido API Gateway.

Los claims llegan en el requestContext, que arma API Gateway despues de validar
el token con el authorizer de Cognito. El cliente no los puede escribir, la
identidad sale solo de aca, nunca de headers ni del body.
"""

from typing import Optional

from aws_lambda_powertools.event_handler import APIGatewayHttpResolver
from aws_lambda_powertools.event_handler.exceptions import UnauthorizedError

from barriofix import dynamo
from barriofix.errores import NotFoundError


def claims(app: APIGatewayHttpResolver) -> dict:
    ctx = app.current_event.request_context.authorizer
    datos = getattr(ctx, "jwt_claim", None) or {}
    if not datos:
        raise UnauthorizedError("Falta el token de acceso")
    return datos


def sub(app: APIGatewayHttpResolver) -> str:
    valor = claims(app).get("sub")
    if not valor:
        raise UnauthorizedError("Token sin sub")
    return valor


def perfil(app: APIGatewayHttpResolver) -> dict:
    """Perfil del usuario desde DynamoDB. 404 si la cuenta todavia no tiene
    perfil (recien registrada en Cognito), el front muestra el formulario."""
    item = dynamo.get_item(f"USER#{sub(app)}", "PERFIL")
    if item is None:
        raise NotFoundError("El usuario no tiene perfil cargado")
    return item


def perfil_opcional(app: APIGatewayHttpResolver) -> Optional[dict]:
    return dynamo.get_item(f"USER#{sub(app)}", "PERFIL")
