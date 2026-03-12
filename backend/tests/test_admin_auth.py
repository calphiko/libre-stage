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

#!/usr/bin/env python3
"""
Test Script für Admin-Endpoint Authentifizierung
"""

def test_admin_endpoint_auth(client, test_user, auth_headers):
    """Testet ob Admin-Endpoint mit Token-Auth funktioniert"""

    # Admin-Endpoint mit gültigem Token aufrufen
    response = client.get("/admin/users", headers=auth_headers)
    assert response.status_code == 200
    users = response.json()
    assert isinstance(users, list)
    assert len(users) >= 1

if __name__ == "__main__":
    print("⚠️  Führe diesen Test mit pytest aus, nicht direkt!")
