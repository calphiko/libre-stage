"""add_availability_table

Adds the ``availability`` table that tracks whether a band member is
available, unavailable, or tentatively available for a rehearsal or gig.
An optional substitute (free-text name or registered user) can be stored
when the member is unavailable.

Revision ID: e1f2a3b4c5d6
Revises: 0ba4c6c97dad
Create Date: 2026-07-07 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e1f2a3b4c5d6'
down_revision: Union[str, Sequence[str], None] = '0f449d875a38'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create the availability table."""
    op.create_table(
        'availability',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('event_type', sa.String(length=32), nullable=False),
        sa.Column('event_id', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(length=32), nullable=False),
        sa.Column('comment', sa.Text(), nullable=True),
        sa.Column('substitute_name', sa.String(length=512), nullable=True),
        sa.Column('substitute_user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'event_type', 'event_id', name='_availability_uc'),
    )
    op.create_index('ix_availability_id', 'availability', ['id'], unique=False)
    op.create_index('ix_availability_event', 'availability', ['event_type', 'event_id'], unique=False)
    op.create_index('ix_availability_user', 'availability', ['user_id'], unique=False)


def downgrade() -> None:
    """Drop the availability table."""
    op.drop_index('ix_availability_user', table_name='availability')
    op.drop_index('ix_availability_event', table_name='availability')
    op.drop_index('ix_availability_id', table_name='availability')
    op.drop_table('availability')


