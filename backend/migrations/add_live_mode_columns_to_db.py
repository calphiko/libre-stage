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
Migration: Fügt Live-Mode-Spalten zur set_songs Tabelle hinzu

Neue Spalten:
- eingeschoben (Boolean, nullable): Markiert, ob Song live eingeschoben wurde
- uebersprungen (Boolean, nullable): Markiert, ob Song übersprungen wurde
- feedback (Integer, nullable): Feedback-Bewertung für den Song

Ausführung:
    python backend/migrations/add_live_mode_columns_to_db.py
    python backend/migrations/add_live_mode_columns_to_db.py /pfad/zur/app.db
"""

import sqlite3
import sys
import argparse
from pathlib import Path

# Standard-Pfad zur Datenbank
DEFAULT_DB_PATH = Path(__file__).parent.parent / "db" / "app.db"


def add_live_mode_columns(db_path: Path):
    """Fügt die Live-Mode-Spalten zur set_songs Tabelle hinzu"""

    if not db_path.exists():
        print(f"❌ Datenbank nicht gefunden: {db_path}")
        sys.exit(1)

    print(f"📊 Verbinde mit Datenbank: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        # Prüfe, ob die Tabelle existiert
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='set_songs'
        """)
        if not cursor.fetchone():
            print("❌ Tabelle 'set_songs' existiert nicht!")
            conn.close()
            sys.exit(1)

        # Prüfe vorhandene Spalten
        cursor.execute("PRAGMA table_info(set_songs)")
        existing_columns = [col[1] for col in cursor.fetchall()]
        print(f"✓ Vorhandene Spalten: {', '.join(existing_columns)}")

        # Füge Spalten hinzu (nur wenn noch nicht vorhanden)
        columns_to_add = [
            ("eingeschoben", "BOOLEAN"),
            ("uebersprungen", "BOOLEAN"),
            ("feedback", "INTEGER")
        ]

        added_count = 0
        for col_name, col_type in columns_to_add:
            if col_name not in existing_columns:
                print(f"➕ Füge Spalte hinzu: {col_name} ({col_type})")
                cursor.execute(f"""
                    ALTER TABLE set_songs 
                    ADD COLUMN {col_name} {col_type} DEFAULT NULL
                """)
                added_count += 1
            else:
                print(f"⏭️  Spalte '{col_name}' existiert bereits")

        conn.commit()

        # Bestätige Änderungen
        cursor.execute("PRAGMA table_info(set_songs)")
        updated_columns = [col[1] for col in cursor.fetchall()]

        print(f"\n✅ Migration erfolgreich!")
        print(f"   Hinzugefügte Spalten: {added_count}")
        print(f"   Aktuelle Spalten: {', '.join(updated_columns)}")

    except sqlite3.Error as e:
        print(f"❌ Fehler bei der Migration: {e}")
        conn.rollback()
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Fügt Live-Mode-Spalten zur set_songs Tabelle hinzu"
    )
    parser.add_argument(
        "db_path",
        nargs="?",
        type=Path,
        default=DEFAULT_DB_PATH,
        help=f"Pfad zur Datenbank (Standard: {DEFAULT_DB_PATH})"
    )

    args = parser.parse_args()

    print("=" * 60)
    print("  Migration: Live-Mode-Spalten für set_songs")
    print("=" * 60)
    add_live_mode_columns(args.db_path)
    print("=" * 60)

