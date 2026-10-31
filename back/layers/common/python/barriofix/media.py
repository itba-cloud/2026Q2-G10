"""URLs prefirmadas de S3 para las fotos.

Firmar una URL es una operacion LOCAL (no hace red), asi que anda igual desde
una Lambda en la VPC sin salida a internet. El navegador despues sube/baja
directo contra S3.
"""

import boto3

from barriofix import config

_s3 = boto3.client("s3", region_name=config.REGION)

# Tope de seguridad, no de uso: el front redimensiona y comprime cada foto antes
# de subirla, asi que llegan con unos cientos de KB y nunca se acercan a esto
MAX_BYTES = 50 * 1024 * 1024


def presigned_post(key: str, metadata: dict, expires: int = 300) -> dict:
    """Datos para que el navegador suba una foto directo a S3 con condiciones:
    tamaño acotado, solo imagenes, y la key exacta. metadata se guarda en el
    objeto (x-amz-meta-*) para que foto_subida la lea."""
    fields = {f"x-amz-meta-{k}": str(v) for k, v in metadata.items()}
    conditions = [
        ["content-length-range", 1, MAX_BYTES],
        ["starts-with", "$Content-Type", "image/"],
    ]
    conditions += [{f"x-amz-meta-{k}": str(v)} for k, v in metadata.items()]
    return _s3.generate_presigned_post(
        config.MEDIA_BUCKET, key, Fields=fields, Conditions=conditions, ExpiresIn=expires
    )


def presigned_get(key: str, expires: int = 3600) -> str:
    return _s3.generate_presigned_url(
        "get_object", Params={"Bucket": config.MEDIA_BUCKET, "Key": key}, ExpiresIn=expires
    )


def metadata(key: str) -> dict:
    """Metadata x-amz-meta-* de un objeto (la usa foto_subida)."""
    resp = _s3.head_object(Bucket=config.MEDIA_BUCKET, Key=key)
    return resp.get("Metadata", {})
