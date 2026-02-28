import re
from typing import Tuple

def validate_password(password: str) -> Tuple[bool, str]:
    """
    Validiert Passwort-Komplexität gemäß Frontend-Regeln.

    Anforderungen:
    - Mindestens 8 Zeichen
    - Mindestens ein Großbuchstabe
    - Mindestens ein Kleinbuchstabe
    - Mindestens eine Ziffer
    - Mindestens ein Sonderzeichen

    Returns:
        (is_valid, error_message)
    """
    if len(password) < 8:
        return False, "Passwort muss mindestens 8 Zeichen lang sein"

    if not re.search(r"[A-Z]", password):
        return False, "Passwort muss mindestens einen Großbuchstaben enthalten"

    if not re.search(r"[a-z]", password):
        return False, "Passwort muss mindestens einen Kleinbuchstaben enthalten"

    if not re.search(r"\d", password):
        return False, "Passwort muss mindestens eine Ziffer enthalten"

    if not re.search(r"[-_!@#$%^&*(),.?\":{}|<>]", password):
        return False, "Passwort muss mindestens ein Sonderzeichen enthalten"

    return True, ""