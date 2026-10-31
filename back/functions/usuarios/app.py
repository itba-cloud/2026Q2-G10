"""Dominio usuarios: el perfil propio y el alta de perfil tras el registro en Cognito."""

from datetime import datetime, timezone

from aws_lambda_powertools import Logger

from barriofix import auth, dynamo, serializers
from barriofix.api import crear_app
from barriofix.schemas import RegistroIn

logger = Logger(service="usuarios")
app = crear_app()


@app.get("/api/auth/me")
def me():
    sub = auth.sub(app)
    item = auth.perfil(app)  # 404 si todavia no se completo el registro
    return serializers.usuario_out(sub, item)


@app.post("/api/auth/registro")
def registro(datos: RegistroIn):
    """Crea el perfil en DynamoDB para una cuenta ya registrada en Cognito.
    El sub y el email salen del token validado, nunca del body."""
    sub = auth.sub(app)
    claims = auth.claims(app)

    item = {
        "PK": f"USER#{sub}",
        "SK": "PERFIL",
        "nombre": datos.nombre,
        "apellido": datos.apellido,
        "email": claims.get("email", ""),
        "telefono": datos.telefono or "",
        "rol": datos.rol,
        "fecha_registro": datetime.now(timezone.utc).isoformat(),
    }
    if datos.rol == "PROFESIONAL":
        item["disponible"] = True
        item["descripcion"] = datos.descripcion_profesional or ""
        if datos.categorias:
            item["categorias"] = set(datos.categorias)

    # attribute_not_exists: reintentar el registro es seguro, no pisa el perfil
    dynamo.put(item, condition="attribute_not_exists(PK)")
    return serializers.usuario_out(sub, item), 201


@logger.inject_lambda_context
def handler(event, context):
    return app.resolve(event, context)
