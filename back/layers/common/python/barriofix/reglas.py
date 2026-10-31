"""Maquina de estados de una solicitud, como funciones puras (sin AWS).

Define las transiciones permitidas. La usa el dominio flujo para decidir, y se
testea sin levantar nada. Es la version DynamoDB de la logica que en el TP2
estaba en transiciones.py.
"""

PENDIENTE = "PENDIENTE"
ASIGNADO = "ASIGNADO"
EN_PROGRESO = "EN_PROGRESO"
RESUELTO = "RESUELTO"
CANCELADO = "CANCELADO"

FINALES = {RESUELTO, CANCELADO}

# destino -> estados de origen permitidos
TRANSICIONES = {
    ASIGNADO: {PENDIENTE},
    EN_PROGRESO: {ASIGNADO},
    RESUELTO: {EN_PROGRESO},
    PENDIENTE: {ASIGNADO, EN_PROGRESO},        # liberar: vuelve al pool
    CANCELADO: {PENDIENTE, ASIGNADO, EN_PROGRESO},
}


def puede(origen: str, destino: str) -> bool:
    return origen in TRANSICIONES.get(destino, set())
