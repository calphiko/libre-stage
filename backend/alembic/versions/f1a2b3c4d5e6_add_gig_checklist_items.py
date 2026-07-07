"""add_gig_checklist_items

Adds the ``gig_checklist_items`` table – per-gig preparation tasks with
optional category, assignee, done-flag and a due datetime used by the
Gantt-chart view in the frontend.

Revision ID: f1a2b3c4d5e6
Revises: e1f2a3b4c5d6
Create Date: 2026-07-07 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f1a2b3c4d5e6'
down_revision: Union[str, Sequence[str], None] = 'e1f2a3b4c5d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create gig_checklist_items table."""
    op.create_table(
        'gig_checklist_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('gig_id', sa.Integer(), sa.ForeignKey('gigs.id'), nullable=False),
        sa.Column('title', sa.String(length=512), nullable=False),
        sa.Column('category', sa.String(length=128), nullable=True),
        sa.Column('assignee_user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=True),
        sa.Column('assignee_name', sa.String(length=512), nullable=True),
        sa.Column('done', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('due_datetime', sa.DateTime(), nullable=True),
        sa.Column('position', sa.Integer(), nullable=False, server_default='0'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_gig_checklist_items_id', 'gig_checklist_items', ['id'], unique=False)
    op.create_index('ix_gig_checklist_items_gig', 'gig_checklist_items', ['gig_id'], unique=False)


def downgrade() -> None:
    """Drop gig_checklist_items table."""
    op.drop_index('ix_gig_checklist_items_gig', table_name='gig_checklist_items')
    op.drop_index('ix_gig_checklist_items_id', table_name='gig_checklist_items')
    op.drop_table('gig_checklist_items')

