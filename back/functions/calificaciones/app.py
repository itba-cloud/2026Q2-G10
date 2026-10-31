"""Dominio calificaciones: calificar un trabajo resuelto.

La calificacion vive dentro de la META (se muestra en los listados). Las tres
reglas (solo el cliente dueño, solo si esta RESUELTO, una sola vez) van en una
condicion atomica.
"""

from datetime import datetime, timezone

from aws_lambda_powertools import Logger
from aws_lambda_powertools.event_handler.exceptions import NotFoundError

from barriofix import auth, dynamo, reglas
from barriofix.api import crear_app
from barriofix.schemas import CalificacionIn

logger = Logger(service="calificaciones")
app = crear_app()


@app.post("/api/solicitudes/<id_sol>/calificacion")
def calificar(id_sol: str, datos: CalificacionIn):
    sub = auth.sub(app)
    cal = {
        "id_calificacion": id_sol,
        "puntuacion": datos.puntuacion,
        "comentario": datos.comentario,
        "fecha_calificacion": datetime.now(timezone.utc).isoformat(),
    }
    # 409 si no esta RESUELTO, si no es el cliente dueño, o si ya tiene calificacion
    dynamo.update(
        key={"PK": f"SOL#{id_sol}", "SK": "META"},
        expression="SET calificacion = :c",
        values={":c": cal, ":r": reglas.RESUELTO, ":sub": sub},
        condition="estado = :r AND id_cliente = :sub AND attribute_not_exists(calificacion)",
    )
    return cal, 201


@app.get("/api/solicitudes/<id_sol>/calificacion")
def obtener(id_sol: str):
    meta = dynamo.get_item(f"SOL#{id_sol}", "META")
    if meta is None or "calificacion" not in meta:
        raise NotFoundError("La solicitud no tiene calificacion")
    return meta["calificacion"]


@logger.inject_lambda_context
def handler(event, context):
    return app.resolve(event, context)
