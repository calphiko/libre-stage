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
Script zum Entfernen von localStorage Token-Handling aus allen Svelte-Seiten
"""

import re
import os
from pathlib import Path

# Dateien die aktualisiert werden müssen
files_to_update = [
    "frontend/src/routes/benutzer/+page.svelte",
    "frontend/src/routes/songs/+page.svelte",
    "frontend/src/routes/proben/+page.svelte",
    "frontend/src/routes/gigs/+page.svelte",
    "frontend/src/routes/abstimmungen/+page.svelte",
    "frontend/src/routes/setlist_editor/+page.svelte",
    "frontend/src/routes/setlist_editor/SetList.svelte",
    "frontend/src/lib/components/UserAdminTable.svelte",
]

def remove_token_localstorage(file_path):
    """Entfernt localStorage Token-Zeile und ersetzt token Parameter mit null"""
    if not os.path.exists(file_path):
        print(f"⚠️  Datei nicht gefunden: {file_path}")
        return False

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # 1. Entferne: let token = browser ? localStorage.getItem('token') ?? '' : '';
    content = re.sub(
        r"let token = browser \? localStorage\.getItem\('token'\) \?\? '' : '';?\n?",
        "",
        content
    )

    # 2. Ersetze: if (browser) localStorage.removeItem('token');
    content = re.sub(
        r"if \(browser\) localStorage\.removeItem\('token'\);?\n?",
        "",
        content
    )

    # 3. Ersetze: localStorage.removeItem('token')
    content = re.sub(
        r"localStorage\.removeItem\('token'\);?\n?",
        "",
        content
    )

    # 4. Ersetze API-Calls: getUser(token) -> getUser()
    content = re.sub(r"getUser\(token\)", "getUser()", content)
    content = re.sub(r"getUserList\(token\)", "getUserList()", content)
    content = re.sub(r"getSongs\(token\)", "getSongs()", content)
    content = re.sub(r"getGigs\(token", "getGigs(null", content)
    content = re.sub(r"getRehearsalList\(token\)", "getRehearsalList()", content)
    content = re.sub(r"getSurveys\(\s*token\s*\)", "getSurveys()", content)

    # 5. Ersetze API-Calls mit token als erstes Argument: func(token, ...) -> func(null, ...)
    content = re.sub(r"(\w+)\(token,", r"\1(null,", content)

    # 6. Füge logout import hinzu falls nicht vorhanden
    if "logout as apiLogout" not in content and "from '$lib/api.js'" in content:
        content = re.sub(
            r"(import \{[^}]+)(\} from '\$lib/api\.js';)",
            r"\1, logout as apiLogout\2",
            content
        )

    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Aktualisiert: {file_path}")
        return True
    else:
        print(f"ℹ️  Keine Änderungen: {file_path}")
        return False

if __name__ == "__main__":
    print("🔄 Entferne localStorage Token-Handling aus Svelte-Seiten...\n")

    updated = 0
    for file_path in files_to_update:
        if remove_token_localstorage(file_path):
            updated += 1

    print(f"\n✨ {updated} von {len(files_to_update)} Dateien aktualisiert")

