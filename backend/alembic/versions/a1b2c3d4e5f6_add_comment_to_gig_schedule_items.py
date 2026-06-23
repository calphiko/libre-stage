"""add_comment_to_gig_schedule_items

Revision ID: a1b2c3d4e5f6
Revises: 7f61e0947ca6
Create Date: 2026-06-23 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = '7f61e0947ca6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add comment column to gig_schedule_items."""
    with op.batch_alter_table('gig_schedule_items', schema=None) as batch_op:
        batch_op.add_column(sa.Column('comment', sa.Text(), nullable=True))


def downgrade() -> None:
    """Remove comment column from gig_schedule_items."""
    with op.batch_alter_table('gig_schedule_items', schema=None) as batch_op:
        batch_op.drop_column('comment')

