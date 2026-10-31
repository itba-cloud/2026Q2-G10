"""Traduccion de errores de DynamoDB a respuestas HTTP."""

from aws_lambda_powertools.event_handler.exceptions import (
    BadRequestError,
    NotFoundError,
)
from botocore.exceptions import ClientError


class ConflictoError(Exception):
    """409 cuando una escritura condicional fallo, otro gano la carrera o ya existia."""


def es_condicion_fallida(e: ClientError) -> bool:
    codigo = e.response.get("Error", {}).get("Code", "")
    return codigo in ("ConditionalCheckFailedException", "TransactionCanceledException")


__all__ = ["BadRequestError", "NotFoundError", "ConflictoError", "es_condicion_fallida"]
