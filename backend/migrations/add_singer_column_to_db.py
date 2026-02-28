import sqlite3
import sys
import argparse
from pathlib import Path

# Standard-Pfad zur Datenbank
DEFAULT_DB_PATH = Path(__file__).parent.parent / "db" / "app.db"


def add_singer_column(db_path: Path):
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
            WHERE type='table' AND name='users'
        """)
        if not cursor.fetchone():
            print("❌ Tabelle 'users' existiert nicht!")
            conn.close()
            sys.exit(1)

        # Prüfe vorhandene Spalten
        cursor.execute("PRAGMA table_info(users)")
        existing_columns = [col[1] for col in cursor.fetchall()]
        print(f"✓ Vorhandene Spalten: {', '.join(existing_columns)}")

        # Füge Spalten hinzu (nur wenn noch nicht vorhanden)
        columns_to_add = [
            ("is_singer", "BOOLEAN"),
        ]

        added_count = 0
        for col_name, col_type in columns_to_add:
            if col_name not in existing_columns:
                print(f"➕ Füge Spalte hinzu: {col_name} ({col_type})")
                cursor.execute(f"""
                    ALTER TABLE users 
                    ADD COLUMN {col_name} {col_type} DEFAULT 0
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
        description="Fügt Sänger-Spalten zur users Tabelle hinzu"
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
    print("  Migration: Singer-Spalten für users")
    print("=" * 60)
    add_singer_column(args.db_path)
    print("=" * 60)