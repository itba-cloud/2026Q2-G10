"""Puente HTTPS de la Hosted UI de Cognito.

Recibe GET /callback con ?code=... desde Cognito, intercambia el code por los
tokens en /oauth2/token (autenticando con client id y client secret), y redirige
al front con los tokens en el fragment.

Va fuera de la VPC porque llama a Cognito por internet y no toca DynamoDB. Solo
usa stdlib y boto3, sin dependencias extra.
"""

import base64
import json
import os
import urllib.parse
import urllib.request

import boto3

TOKEN_ENDPOINT = os.environ["TOKEN_ENDPOINT"]
CLIENT_ID = os.environ["CLIENT_ID"]
REDIRECT_URI = os.environ["REDIRECT_URI"]
FRONT_URL = os.environ["FRONT_URL"]
SECRET_ARN = os.environ["CLIENT_SECRET_ARN"]

_secrets = boto3.client("secretsmanager")
_client_secret: str | None = None


def _secret() -> str:
    # Cacheado a nivel de modulo, se lee una vez por instancia caliente
    global _client_secret
    if _client_secret is None:
        _client_secret = _secrets.get_secret_value(SecretId=SECRET_ARN)["SecretString"]
    return _client_secret


def _redirect(url: str):
    return {"statusCode": 302, "headers": {"Location": url}, "body": ""}


def handler(event, context):
    params = event.get("queryStringParameters") or {}
    code = params.get("code")
    state = params.get("state", "")

    # Sin code no se llama a Cognito, rechazo temprano y barato ante floods
    if not code:
        error = params.get("error", "missing_code")
        return _redirect(f"{FRONT_URL}#error={urllib.parse.quote(error)}")

    datos = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": code,
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
    }).encode()

    basic = base64.b64encode(f"{CLIENT_ID}:{_secret()}".encode()).decode()
    req = urllib.request.Request(
        TOKEN_ENDPOINT,
        data=datos,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": f"Basic {basic}",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            tokens = json.loads(resp.read().decode())
    except Exception:  # noqa: BLE001  cualquier fallo del intercambio se devuelve como error al front
        return _redirect(f"{FRONT_URL}#error=token_exchange_failed")

    # El front lee estos valores del fragment y valida el state contra el que guardo
    fragment = urllib.parse.urlencode({
        "id_token": tokens.get("id_token", ""),
        "access_token": tokens.get("access_token", ""),
        "refresh_token": tokens.get("refresh_token", ""),
        "expires_in": tokens.get("expires_in", ""),
        "state": state,
    })
    return _redirect(f"{FRONT_URL}#{fragment}")
