"""ULID ordenable por fecha de creacion, sin coordinacion entre instancias.

Los primeros 48 bits son el timestamp en milisegundos, los 80 restantes son
aleatorios. Como el prefijo temporal es lo mas significativo, ordenar los ULID
como strings equivale a ordenarlos por fecha. Sirve de sort key en los GSIs.
"""

import os
import time

# Alfabeto de Crockford base32 (sin I, L, O, U para evitar confusiones)
_ALFABETO = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"


def ulid() -> str:
    timestamp = int(time.time() * 1000)
    aleatorio = int.from_bytes(os.urandom(10), "big")
    valor = (timestamp << 80) | aleatorio

    chars = []
    for _ in range(26):
        chars.append(_ALFABETO[valor & 0x1F])
        valor >>= 5
    return "".join(reversed(chars))
