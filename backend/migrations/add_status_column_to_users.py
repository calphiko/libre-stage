"""
Migration: add status column to users table

Adds a `status` column (VARCHAR(32), NOT NULL, DEFAULT 'active') to the
`users` table and sets all existing rows to 'active'.

Usage:
    python -m backend.migrations.add_status_column_to_users
"""

import sqlite3
import os
import logging

logger = logging.getLogger(__name__)


def run(db_path: str = None):
    if db_path is None:
        db_path = os.environ.get(
            "DB_PATH",
            os.path.join(os.path.dirname(__file__), "..", "db", "libre_stage.db"),
        )

    db_path = os.path.abspath(db_path)
    logger.info(f"Running migration on: {db_path}")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Check if column already exists
    cursor.execute("PRAGMA table_info(users)")
    columns = [row[1] for row in cursor.fetchall()]

    if "status" in columns:
        logger.info("Column 'status' already exists – skipping.")
        conn.close()
        return

    logger.info("Adding column 'status' to table 'users' …")
    cursor.execute(
        "ALTER TABLE users ADD COLUMN status VARCHAR(32) NOT NULL DEFAULT 'active'"
    )

    # Ensure all existing rows are explicitly set to 'active'
    cursor.execute("UPDATE users SET status = 'active' WHERE status IS NULL")

    conn.commit()
    conn.close()
    logger.info("Migration complete: 'status' column added, all existing users set to 'active'.")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run()

