"""Preserve first-touch H5 attribution on newly created reports."""

from alembic import op


revision = "20261116_report_attribution"
down_revision = "20261116_visitor_numbers"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE landing_visits ADD COLUMN region_code TEXT CHECK (region_code ~ '^[A-Z]{2}$')")
    op.execute("ALTER TABLE landing_visitors ADD COLUMN first_source TEXT, ADD COLUMN first_campaign TEXT")
    op.execute("""
        ALTER TABLE life_reports
        ADD COLUMN landing_visitor_number TEXT,
        ADD COLUMN landing_source TEXT,
        ADD COLUMN landing_campaign TEXT,
        ADD COLUMN landing_region TEXT
    """)


def downgrade():
    op.execute("""
        ALTER TABLE life_reports
        DROP COLUMN landing_visitor_number,
        DROP COLUMN landing_source,
        DROP COLUMN landing_campaign,
        DROP COLUMN landing_region
    """)
    op.execute("ALTER TABLE landing_visitors DROP COLUMN first_source, DROP COLUMN first_campaign")
    op.execute("ALTER TABLE landing_visits DROP COLUMN region_code")
