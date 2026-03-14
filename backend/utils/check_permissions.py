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


"""
Permission check helpers.

Provides simple role-based access control functions used by API
route handlers to guard admin- and editor-only endpoints.
"""


def check_admin(current: dict) -> bool:
    """
    Return ``True`` if the current user has the ``admin`` role.

    Args:
        current (dict): Token payload dict with at least a
            ``user_group`` key (as returned by
            :func:`auth.get_current_user`).

    Returns:
        bool: ``True`` for admins, ``False`` for all other roles.
    """
    if current["user_group"].upper() == "ADMIN":
        return True
    return False


def check_editor(current: dict) -> bool:
    """
    Return ``True`` if the current user has the ``admin`` or ``editor``
    role.

    Args:
        current (dict): Token payload dict with at least a
            ``user_group`` key.

    Returns:
        bool: ``True`` for admins and editors, ``False`` otherwise.
    """
    if current["user_group"].upper() in ["ADMIN", "EDITOR"]:
        return True
    return False
