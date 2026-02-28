#!/usr/bin/env python3
"""
Migration Script: Bereinige korrupte SetSongs ohne Song-Referenz

Entfernt SetSong-Einträge, die auf nicht-existierende Songs verweisen.
Dies kann passieren, wenn Songs gelöscht wurden, aber SetSong-Einträge bestehen bleiben.

Usage:
    python cleanup_corrupted_setsongs.py [path/to/app.db]
"""

import sqlite3
import sys
from pathlib import Path


def cleanup_corrupted_setsongs(db_path: str):
    """Entfernt SetSongs die auf nicht-existierende Songs verweisen"""

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        # Finde SetSongs ohne gültige Song-Referenz
        cursor.execute("""
            SELECT ss.id, ss.id_set, ss.id_song, ss.position
            FROM set_songs ss
            LEFT JOIN songs s ON ss.id_song = s.id
            WHERE s.id IS NULL
        """)

        corrupted = cursor.fetchall()

        if not corrupted:
            print("✅ Keine korrupten SetSongs gefunden!")
            return

        print(f"⚠️  Gefunden: {len(corrupted)} korrupte SetSongs ohne Song-Referenz:")
        for ss_id, set_id, song_id, position in corrupted:
            print(f"   - SetSong ID {ss_id}: Set={set_id}, verweist auf nicht-existierenden Song ID {song_id}, Position {position}")

        # Bestätigung
        answer = input(f"\n🗑️  Möchtest du diese {len(corrupted)} korrupten Einträge löschen? (ja/nein): ")

        if answer.lower() not in ['ja', 'j', 'yes', 'y']:
            print("❌ Abgebrochen. Keine Änderungen vorgenommen.")
            return

        # Lösche korrupte SetSongs
        cursor.execute("""
            DELETE FROM set_songs
            WHERE id IN (
                SELECT ss.id
                FROM set_songs ss
                LEFT JOIN songs s ON ss.id_song = s.id
                WHERE s.id IS NULL
            )
        """)

        deleted_count = cursor.rowcount
        conn.commit()

        print(f"✅ {deleted_count} korrupte SetSongs erfolgreich gelöscht!")

        # Zeige verbleibende SetSongs pro Set
        cursor.execute("""
            SELECT id_set, COUNT(*) as count
            FROM set_songs
            GROUP BY id_set
        """)

        print("\n📊 Verbleibende SetSongs pro Set:")
        for set_id, count in cursor.fetchall():
            print(f"   Set {set_id}: {count} Songs")

    except Exception as e:
        print(f"❌ Fehler bei der Migration: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) > 1:
        db_path = sys.argv[1]
    else:
        # Standard-Pfad
        script_dir = Path(__file__).parent.parent
        db_path = script_dir / "db" / "app.db"

    if not Path(db_path).exists():
        print(f"❌ Datenbank nicht gefunden: {db_path}")
        sys.exit(1)

    print(f"🔍 Prüfe Datenbank: {db_path}\n")
    cleanup_corrupted_setsongs(str(db_path))

