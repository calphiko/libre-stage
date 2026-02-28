#!/usr/bin/env python3
import sqlite3
import argparse
import re
import sys

ALLOWED = ["Calle", "Dana", "Oliver"]
ALIASES = {
    # gebräuchliche Kurzformen / Tippfehler / Varianten
    "olli": "Oliver",
    "oliver": "Oliver",
    "o": "Oliver",
    "calle": "Calle",
    "c": "Calle",
    "dana": "Dana",
    "d": "Dana",
    # weitere Varianten können hier ergänzt werden
}

# Trenner: +, ,  /  "und"  & oder auch nur Leerzeichen (letzteres als Fallback)
SPLIT_RE = re.compile(
    r'\s*\+\s*|\s*,\s*|\s*\/\s*|\s+und\s+|\s*&\s*|\s+',
    flags=re.IGNORECASE
)
# entferne alles außer Buchstaben (inkl. deutsche Umlaute)
CLEAN_RE = re.compile(r'[^A-Za-zÄÖÜäöüß]')

def normalize_singer(value: str) -> str:
    if value is None:
        return ""
    v = value.strip()
    if v == "" or v == "-":
        return ""
    # Fange alle Varianten mit "alle" (z. B. "alle", "alle anderen", "im Zweifel alle")
    if re.search(r'\balle\b', v, re.IGNORECASE):
        return " + ".join(ALLOWED)

    parts = SPLIT_RE.split(v)
    normalized = []
    seen = set()
    for p in parts:
        p = p.strip()
        if not p:
            continue
        # Reinige (z.B. "Dana0" -> "Dana")
        key = CLEAN_RE.sub('', p).lower()
        if not key:
            continue
        # Alias abgleichen (inkl. einzelner Buchstaben)
        name = ALIASES.get(key)
        if name is None:
            # Direkter Vergleich: z.B. "Calle" oder "Oliver"
            cand = p.capitalize()
            if cand in ALLOWED:
                name = cand
        # Falls unbekannt (z.B. "Chor"), skip
        if name is None or name not in ALLOWED:
            continue
        if name not in seen:
            seen.add(name)
            normalized.append(name)

    # Ergebniss als Leerstring statt "": join gibt "" zurück, das ist gewünscht
    return " + ".join(normalized)

def valid_identifier(name: str) -> bool:
    return re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', name) is not None

def main():
    parser = argparse.ArgumentParser(description="Normalisiere singer_lead in einer SQLite-Tabelle")
    parser.add_argument("--db", required=True, help="Pfad zur SQLite-Datei")
    parser.add_argument("--table", default="songs", help="Tabellenname (Standard: songs)")
    parser.add_argument("--column", default="singer_lead", help="Quellspalte (Standard: singer_lead)")
    parser.add_argument("--new-column", default="singer_lead_normalized", help="Zielspalte (Standard: singer_lead_normalized)")
    parser.add_argument("--overwrite", action="store_true", help="Überschreibe die Originalspalte statt eine neue Spalte anzulegen")
    args = parser.parse_args()

    table = args.table
    column = args.column
    new_column = args.new_column

    for ident in (table, column, new_column):
        if not valid_identifier(ident):
            print(f"Ungültiger Identifier: {ident}", file=sys.stderr)
            sys.exit(1)

    try:
        conn = sqlite3.connect(args.db)
    except Exception as e:
        print(f"Fehler beim Öffnen der DB: {e}", file=sys.stderr)
        sys.exit(1)

    cur = conn.cursor()

    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", (table,))
    if cur.fetchone() is None:
        print(f"Tabelle '{table}' existiert nicht in der DB.", file=sys.stderr)
        conn.close()
        sys.exit(1)

    target_column = column if args.overwrite else new_column
    if not args.overwrite:
        cur.execute(f"PRAGMA table_info({table});")
        cols = [row[1] for row in cur.fetchall()]
        if new_column not in cols:
            cur.execute(f"ALTER TABLE {table} ADD COLUMN {new_column} TEXT;")
            conn.commit()
            print(f"Spalte '{new_column}' hinzugefügt.")

    # Hole DISTINCT Werte der Quellspalte
    cur.execute(f"SELECT DISTINCT {column} FROM {table};")
    distinct_values = [row[0] for row in cur.fetchall()]

    mapping = {}
    total_updated = 0
    print("Ermittle Normalisierungen und aktualisiere DB...")
    for orig in distinct_values:
        norm = normalize_singer(orig)
        mapping[orig] = norm

        # Update: NULL behandeln, sonst exakter Vergleich
        if orig is None:
            sql = f"UPDATE {table} SET {target_column} = ? WHERE {column} IS NULL;"
            cur.execute(sql, (norm,))
        else:
            sql = f"UPDATE {table} SET {target_column} = ? WHERE {column} = ?;"
            cur.execute(sql, (norm, orig))

        # sqlite3 rowcount kann -1 liefern; wir zählen die Änderungen grob
        try:
            updated = cur.rowcount if cur.rowcount and cur.rowcount > 0 else 0
        except Exception:
            updated = 0
        total_updated += updated

    conn.commit()

    print("Fertig. Zusammenfassung der Normalisierungen:")
    for orig, norm in mapping.items():
        print(f"- Orig: {repr(orig)} -> Norm: {repr(norm)}")
    print(f"Ungefähr aktualisierte Zeilen: {total_updated} (commit durchgeführt)")

    conn.close()

if __name__ == "__main__":
    main()
