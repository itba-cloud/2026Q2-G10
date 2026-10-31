#!/usr/bin/env bash
# Vacia un bucket de S3 por completo, incluidas las versiones viejas y los
# delete markers, para que se pueda borrar. El bucket de media y el del state
# tienen versionado, y "aws s3 rm --recursive" solo borra la version actual:
# lo demas queda y el destroy falla con "The bucket you tried to delete is not
# empty". Si el bucket no existe, no hace nada.
#
#   bash .github/scripts/vaciar-bucket.sh <bucket>

set -euo pipefail

BUCKET="$1"

if ! aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "${BUCKET} no existe, nada para vaciar."
  exit 0
fi

# Las versiones se borran de a 1000, que es el maximo de delete-objects
while true; do
  OBJETOS=$(aws s3api list-object-versions --bucket "${BUCKET}" --max-items 1000 --output json \
    | jq -c '{Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key, VersionId})), Quiet: true}')
  CANTIDAD=$(echo "${OBJETOS}" | jq '.Objects | length')
  if [ "${CANTIDAD}" -eq 0 ]; then
    break
  fi
  aws s3api delete-objects --bucket "${BUCKET}" --delete "${OBJETOS}" >/dev/null
  echo "${BUCKET}: ${CANTIDAD} versiones borradas"
done

echo "${BUCKET} vacio."
