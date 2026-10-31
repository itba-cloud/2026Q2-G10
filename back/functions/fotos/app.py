"""Dominio fotos: genera la URL prefirmada para subir una foto directo a S3.

La foto NO pasa por API Gateway ni por la Lambda (limites de 10/6 MB): el
navegador la sube a S3 con el presigned POST. El registro en DynamoDB lo hace
la Lambda foto_subida cuando el objeto llega a S3.

El tipo de foto lo decide el rol (igual que en el TP2): el cliente sube ANTES,
el profesional asignado sube DESPUES.
"""

from aws_lambda_powertools import Logger
from aws_lambda_powertools.event_handler.exceptions import NotFoundError, ServiceError

from barriofix import auth, dynamo, media, serializers
from barriofix.api import crear_app
from barriofix.ids import ulid

logger = Logger(service="fotos")
app = crear_app()


@app.get("/api/solicitudes/<id_sol>/fotos")
def listar(id_sol: str):
    meta = dynamo.get_item(f"SOL#{id_sol}", "META")
    if meta is None:
        raise NotFoundError("Solicitud no encontrada")
    return [serializers.foto_out(f) for f in meta.get("fotos", {}).values()]


@app.post("/api/solicitudes/<id_sol>/fotos")
def subir(id_sol: str):
    sub = auth.sub(app)
    meta = dynamo.get_item(f"SOL#{id_sol}", "META")
    if meta is None:
        raise NotFoundError("Solicitud no encontrada")

    if meta.get("id_cliente") == sub:
        tipo = "ANTES"
    elif meta.get("id_profesional") == sub:
        tipo = "DESPUES"
    else:
        raise ServiceError(403, "Solo el cliente o el profesional asignado pueden subir fotos")

    id_foto = ulid()
    key = f"solicitudes/{id_sol}/{id_foto}"
    post = media.presigned_post(key, metadata={"id_foto": id_foto, "tipo": tipo, "solicitud": id_sol})

    # El front usa url + fields para armar el POST a S3; id_foto/tipo para la UI
    return {"id_foto": id_foto, "tipo_foto": tipo, "upload": post}, 201


@logger.inject_lambda_context
def handler(event, context):
    return app.resolve(event, context)
