"""Keep the last observed H5 page without guessing historical exits."""

from alembic import op


revision = "20261117_visit_activity"
down_revision = "20261116_report_attribution"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        ALTER TABLE landing_visits
        ADD COLUMN last_page TEXT,
        ADD COLUMN last_action TEXT,
        ADD COLUMN last_activity_at DOUBLE PRECISION,
        ADD COLUMN last_state TEXT,
        ADD COLUMN last_activity_sequence BIGINT
    """)


def downgrade():
    op.execute("""
        ALTER TABLE landing_visits
        DROP COLUMN last_page,
        DROP COLUMN last_action,
        DROP COLUMN last_activity_at,
        DROP COLUMN last_state,
        DROP COLUMN last_activity_sequence
    """)
