#!/usr/bin/env bash
# Arma el layer comun y, si hiciera falta, las dependencias para Lambda
#
# Las funciones no se empaquetan aca, cada una la zipea su modulo de Terraform
# desde su carpeta. Este script solo arma los layers
#
#   bash back/scripts/build.sh
#
# Powertools y Pydantic vienen del layer publico de AWS (ver variables.tf), asi
# que el deps-layer hoy queda vacio. boto3 ya esta en el runtime

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${AQUI}/build"
PYTHON_IMG="public.ecr.aws/sam/build-python3.12"

rm -rf "${BUILD}"
mkdir -p "${BUILD}/common-layer/python"

# -------- layer comun, copia el paquete barriofix sin bytecode
cp -r "${AQUI}/layers/common/python/barriofix" "${BUILD}/common-layer/python/"
find "${BUILD}/common-layer" -name '__pycache__' -type d -prune -exec rm -rf {} +
echo "layer comun listo en ${BUILD}/common-layer"

# -------- layer de dependencias, solo si requirements-lambda.txt tiene algo
REQ="${AQUI}/requirements-lambda.txt"
if [ -s "${REQ}" ] && grep -qvE '^\s*(#|$)' "${REQ}"; then
  mkdir -p "${BUILD}/deps-layer/python"
  if command -v docker >/dev/null 2>&1; then
    # Con Docker compila los binarios para el entorno real de Lambda
    docker run --rm -v "${AQUI}":/var/task -w /var/task "${PYTHON_IMG}" \
      pip install -r requirements-lambda.txt -t "build/deps-layer/python"
  else
    # Sin Docker, pide las ruedas de Linux x86_64
    pip install -r "${REQ}" \
      --platform manylinux2014_x86_64 --only-binary=:all: \
      --python-version 3.12 --target "${BUILD}/deps-layer/python"
  fi
  echo "layer de dependencias listo en ${BUILD}/deps-layer"
else
  echo "sin dependencias extra (Powertools/Pydantic vienen del layer publico, boto3 del runtime)"
fi
