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
Automatisches Entfernen aller token-Parameter aus Svelte-Dateien und API-Calls
"""

import os
import re

# Dateien die gepatcht werden müssen (basierend auf find_token_refs.py Output)
fixes = {
    "frontend/src/routes/songs/+page.svelte": [
        (r'await createNewSong\(newSong, token\)', r'await createNewSong(newSong, null)'),
        (r'await updateSong\(song\.id, formData, token\)', r'await updateSong(song.id, formData, null)'),
        (r'await deleteSong\(songId, token\)', r'await deleteSong(songId, null)'),
        (r'await acceptSongApproach\(song\.id, token\)', r'await acceptSongApproach(song.id, null)'),
        (r'meta: \{ song, canEdit: canEdit\(\), token \}', r'meta: { song, canEdit: canEdit() }'),
    ],
    "frontend/src/routes/songs/SongDetailsModal.svelte": [
        (r'const \{ song, canEdit, token \} = \$modalStore\[0\]\.meta;', r'const { song, canEdit } = $modalStore[0].meta;'),
        (r'await updateSong\(song\.id, editBuffer, token\)', r'await updateSong(song.id, editBuffer, null)'),
        (r'await deleteSong\(song\.id, token\)', r'await deleteSong(song.id, null)'),
    ],
    "frontend/src/routes/gigs/+page.svelte": [
        (r'await updateGig\(gig\.id, editBuffer, token\)', r'await updateGig(gig.id, editBuffer, null)'),
    ],
    "frontend/src/routes/benutzer/+page.svelte": [
        (r'<PasswordChange \{token\} \{user\} />', r'<PasswordChange {user} />'),
    ],
    "frontend/src/lib/components/PasswordChange.svelte": [
        (r'export let token;', r'// token not needed anymore (cookie-based auth)'),
        (r'let res = await changePasswordByUser\(token, data\);', r'let res = await changePasswordByUser(null, data);'),
    ],
    "frontend/src/lib/components/UserAdminTable.svelte": [
        (r'users = await adminGetAllUsers\(token\);', r'users = await adminGetAllUsers(null);'),
        (r'if \(!token\) \{', r'if (false) { // token check removed'),
    ],
}

def apply_fixes():
    """Wendet alle Fixes auf die entsprechenden Dateien an"""
    fixed_files = 0

    for filepath, patterns in fixes.items():
        if not os.path.exists(filepath):
            print(f"⚠️  Datei nicht gefunden: {filepath}")
            continue

        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content
        changes = 0

        for old_pattern, new_pattern in patterns:
            new_content = re.sub(old_pattern, new_pattern, content)
            if new_content != content:
                changes += 1
                content = new_content

        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ {filepath} ({changes} Änderungen)")
            fixed_files += 1
        else:
            print(f"ℹ️  {filepath} (keine Änderungen nötig)")

    return fixed_files

if __name__ == "__main__":
    print("🔧 Entferne token-Parameter aus Svelte-Dateien...\n")

    fixed = apply_fixes()

    print(f"\n✨ {fixed} Dateien aktualisiert")
    print("\n🔄 Führe find_token_refs.py erneut aus um zu prüfen...\n")

