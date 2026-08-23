"""
add user ownership and public visibility to repertoire setlists

Revision ID: 3a9d7f1e2b54
Revises: 9a4e7f6b2c11
Create Date: 2026-08-22 00:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "3a9d7f1e2b54"
down_revision: Union[str, Sequence[str], None] = "9a4e7f6b2c11"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("repertoire_setlists")}

    # SQLite does not support ALTER COLUMN ... SET NOT NULL or adding a
    # foreign key to an existing table in-place. We therefore keep the column
    # nullable for SQLite and enforce the app-level contract in SQLAlchemy.
    if "user_id" not in columns:
        op.add_column("repertoire_setlists", sa.Column("user_id", sa.Integer(), nullable=True))
    if "is_public" not in columns:
        op.add_column(
            "repertoire_setlists",
            sa.Column("is_public", sa.Boolean(), nullable=False, server_default=sa.false()),
        )

    op.execute(
        "UPDATE repertoire_setlists SET user_id = (SELECT id FROM users ORDER BY id ASC LIMIT 1) WHERE user_id IS NULL OR user_id = 0"
    )

    if bind.dialect.name != "sqlite":
        with op.batch_alter_table("repertoire_setlists", schema=None) as batch_op:
            batch_op.alter_column("user_id", existing_type=sa.Integer(), nullable=False)
            batch_op.create_foreign_key(
                "fk_repertoire_setlists_user_id_users",
                "users",
                ["user_id"],
                ["id"],
            )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("repertoire_setlists")}

    if bind.dialect.name != "sqlite":
        with op.batch_alter_table("repertoire_setlists", schema=None) as batch_op:
            batch_op.drop_constraint("fk_repertoire_setlists_user_id_users", type_="foreignkey")

    if "is_public" in columns:
        op.drop_column("repertoire_setlists", "is_public")
    if "user_id" in columns:
        op.drop_column("repertoire_setlists", "user_id")
