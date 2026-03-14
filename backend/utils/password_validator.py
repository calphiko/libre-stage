# libre-stage - Band rehearsal and gig management software
# Copyright (C) 2026  libre-stage contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import re
from typing import Tuple

"""
Password complexity validator.

Enforces the same password rules that are displayed to the user in the
frontend:

- At least 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one digit
- At least one special character (``-_!@#$%^&*(),.?\":{}|<>``)
"""

def validate_password(password: str) -> Tuple[bool, str]:
    """
    Validate password complexity against the application's rules.

    Args:
        password (str): The plain-text password to validate.

    Returns:
        tuple[bool, str]: A 2-tuple of ``(is_valid, error_message)``.
        *error_message* is an empty string when the password is valid.
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