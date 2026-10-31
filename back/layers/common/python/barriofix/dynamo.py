"""Acceso a DynamoDB. El cliente se crea a nivel de modulo para reutilizarlo
mientras la instancia de la Lambda esta caliente."""

import base64
import json
from typing import Any, Optional

import boto3
from boto3.dynamodb.conditions import Key
from boto3.dynamodb.types import TypeSerializer
from botocore.exceptions import ClientError

from barriofix import config
from barriofix.errores import ConflictoError, es_condicion_fallida

_dynamo = boto3.resource("dynamodb", region_name=config.REGION)
tabla = _dynamo.Table(config.TABLA)

# Cliente de bajo nivel para transacciones (el resource no las expone directo)
_client = boto3.client("dynamodb", region_name=config.REGION)
_ser = TypeSerializer()


def get_item(pk: str, sk: str) -> Optional[dict]:
    return tabla.get_item(Key={"PK": pk, "SK": sk}).get("Item")


def query_collection(pk: str, sk_prefix: Optional[str] = None) -> list[dict]:
    """Todos los items de una particion, opcionalmente filtrados por prefijo de SK."""
    cond = Key("PK").eq(pk)
    if sk_prefix is not None:
        cond = cond & Key("SK").begins_with(sk_prefix)
    return tabla.query(KeyConditionExpression=cond).get("Items", [])


def query_index(index: str, pk_name: str, pk_value: Any, *, limit: int = 50,
                cursor: Optional[str] = None, forward: bool = False) -> tuple[list[dict], Optional[str]]:
    """Query paginada sobre un GSI. Devuelve (items, cursor_siguiente)."""
    params: dict[str, Any] = {
        "IndexName": index,
        "KeyConditionExpression": Key(pk_name).eq(pk_value),
        "ScanIndexForward": forward,
        "Limit": limit,
    }
    if cursor:
        params["ExclusiveStartKey"] = _decode_cursor(cursor)

    resp = tabla.query(**params)
    siguiente = resp.get("LastEvaluatedKey")
    return resp.get("Items", []), (_encode_cursor(siguiente) if siguiente else None)


def put(item: dict, condition: Optional[str] = None) -> None:
    kwargs: dict[str, Any] = {"Item": item}
    if condition:
        kwargs["ConditionExpression"] = condition
    try:
        tabla.put_item(**kwargs)
    except ClientError as e:
        if es_condicion_fallida(e):
            raise ConflictoError("El recurso ya existe")
        raise


def update(key: dict, expression: str, values: dict, condition: Optional[str] = None,
           names: Optional[dict] = None) -> None:
    kwargs: dict[str, Any] = {"Key": key, "UpdateExpression": expression}
    if values:
        kwargs["ExpressionAttributeValues"] = values
    if condition:
        kwargs["ConditionExpression"] = condition
    if names:
        kwargs["ExpressionAttributeNames"] = names
    try:
        tabla.update_item(**kwargs)
    except ClientError as e:
        if es_condicion_fallida(e):
            raise ConflictoError("No se pudo aplicar el cambio (estado cambiado o conflicto)")
        raise


def transact(ops: list[dict]) -> None:
    """Varias escrituras atomicas. Cada op es {'Put': {...}} o {'Update': {...}}
    en forma NATIVA (tipos de Python); aca se serializan al formato del cliente
    de bajo nivel y se agrega el TableName."""
    items = []
    for op in ops:
        (kind, body), = op.items()
        body = dict(body)
        body["TableName"] = config.TABLA
        for campo in ("Item", "Key", "ExpressionAttributeValues"):
            if campo in body:
                body[campo] = {k: _ser.serialize(v) for k, v in body[campo].items()}
        items.append({kind: body})
    try:
        _client.transact_write_items(TransactItems=items)
    except ClientError as e:
        if es_condicion_fallida(e):
            raise ConflictoError("Conflicto con el estado actual (otra operacion gano la carrera)")
        raise


def _encode_cursor(key: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(key, default=str).encode()).decode()


def _decode_cursor(cursor: str) -> dict:
    return json.loads(base64.urlsafe_b64decode(cursor.encode()).decode())
