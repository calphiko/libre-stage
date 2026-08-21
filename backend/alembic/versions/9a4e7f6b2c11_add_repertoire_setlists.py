"""
add repertoire setlists

Revision ID: 9a4e7f6b2c11
Revises: c3d4e5f6a1b2
Create Date: 2026-08-21 15:50:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "9a4e7f6b2c11"
down_revision: Union[str, Sequence[str], None] = "c3d4e5f6a1b2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "repertoire_setlists",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(length=512), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "repertoire_setlist_sets",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("repertoire_setlist_id", sa.Integer(), nullable=False),
        sa.Column("set_id", sa.Integer(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["repertoire_setlist_id"], ["repertoire_setlists.id"]),
        sa.ForeignKeyConstraint(["set_id"], ["sets.id"]),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("repertoire_setlist_sets")
    op.drop_table("repertoire_setlists")
