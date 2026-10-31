"""Configuracion leida del entorno. Las Lambdas la reciben de Terraform."""

import os

TABLA = os.environ.get("TABLA", "barriofix")
MEDIA_BUCKET = os.environ.get("MEDIA_BUCKET", "")
REGION = os.environ.get("AWS_REGION", "us-east-1")

# Tiempo de vida del cache de catalogos en memoria de la Lambda, en segundos
CATALOGOS_TTL = int(os.environ.get("CATALOGOS_TTL", "300"))
