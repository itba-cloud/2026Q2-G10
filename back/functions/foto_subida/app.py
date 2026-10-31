"""Registra una foto en DynamoDB cuando llega a S3.

La dispara S3 (evento ObjectCreated), no API Gateway. Va dentro de la VPC
porque escribe en DynamoDB. Es idempotente: si S3 entrega el evento dos veces,
la condicion attribute_not_exists evita duplicar.
"""

from datetime import datetime, timezone

from aws_lambda_powertools import Logger

from barriofix import dynamo, media

logger = Logger(service="foto-subida")


@logger.inject_lambda_context
def handler(event, context):
    for record in event.get("Records", []):
        key = record["s3"]["object"]["key"]
        # key = solicitudes/<id_solicitud>/<id_foto>
        partes = key.split("/")
        if len(partes) != 3 or partes[0] != "solicitudes":
            logger.warning(f"key inesperada, se ignora: {key}")
            continue
        id_sol, id_foto = partes[1], partes[2]

        meta = media.metadata(key)  # x-amz-meta-* que puso el presigned POST
        foto = {
            "id_foto": id_foto,
            "tipo_foto": meta.get("tipo", "OTRA"),
            "nombre_archivo": meta.get("nombre_archivo", id_foto),
            "s3_key": key,
            "fecha_subida": datetime.now(timezone.utc).isoformat(),
        }

        try:
            dynamo.update(
                key={"PK": f"SOL#{id_sol}", "SK": "META"},
                expression="SET fotos.#f = :foto",
                values={":foto": foto},
                names={"#f": id_foto},
                condition="attribute_exists(PK) AND attribute_not_exists(fotos.#f)",
            )
        except Exception as e:  # noqa: BLE001  evento duplicado o solicitud inexistente: no reintentar
            logger.warning(f"no se registro la foto {key}: {e}")
    return {"ok": True}
