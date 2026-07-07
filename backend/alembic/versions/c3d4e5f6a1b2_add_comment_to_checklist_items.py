"""add comment to gig_checklist_items

Revision ID: c3d4e5f6a1b2
Revises: f1a2b3c4d5e6
Create Date: 2026-07-07

"""
from alembic import op
import sqlalchemy as sa

revision = 'c3d4e5f6a1b2'
down_revision = 'f1a2b3c4d5e6'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('gig_checklist_items', schema=None) as batch_op:
        batch_op.add_column(sa.Column('comment', sa.Text(), nullable=True))


def downgrade():
    with op.batch_alter_table('gig_checklist_items', schema=None) as batch_op:
        batch_op.drop_column('comment')

