"""Trigger pre sign-up de Cognito, autoconfirma las cuentas nuevas.

Para la demo no dependemos del envio de codigos por email. No usa Powertools ni
AWS, solo marca el evento y lo devuelve.
"""


def handler(event, context):
    event["response"]["autoConfirmUser"] = True
    # Si el pool tuviera email como atributo verificable, tambien lo marcamos
    if "email" in event["request"].get("userAttributes", {}):
        event["response"]["autoVerifyEmail"] = True
    return event
