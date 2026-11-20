"""Store manual LINE report delivery and index its interaction events."""
from alembic import op

revision = "20261120_line_delivery"
down_revision = "20261120_line_contact"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        ALTER TABLE life_reports
        ADD COLUMN line_confirmed_at DOUBLE PRECISION,
        ADD COLUMN line_sent_at DOUBLE PRECISION,
        ADD CONSTRAINT life_reports_line_sent_requires_confirmation
            CHECK (line_sent_at IS NULL OR line_confirmed_at IS NOT NULL)
    """)
    op.execute("""
        CREATE INDEX landing_activity_line_events ON landing_visit_activity(received_at, visit_id)
        WHERE page='preview_report' AND kind='action' AND action IN ('open_line_contact','line_qr_shown')
    """)


def downgrade():
    op.execute("DROP INDEX landing_activity_line_events")
    op.execute("""
        ALTER TABLE life_reports
        DROP CONSTRAINT life_reports_line_sent_requires_confirmation,
        DROP COLUMN line_sent_at,
        DROP COLUMN line_confirmed_at
    """)
