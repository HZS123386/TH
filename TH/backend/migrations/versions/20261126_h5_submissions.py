"""Associate a browser submission with its accepted report."""

from alembic import op

revision = "20261126_h5_submissions"
down_revision = "20261123_tarot_fulfillment"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TABLE life_report_submissions (
            owner TEXT NOT NULL,
            submission_id UUID NOT NULL,
            report_id TEXT NOT NULL REFERENCES life_reports(id) ON DELETE CASCADE,
            PRIMARY KEY (owner, submission_id)
        )
    """)
    op.execute("CREATE INDEX life_report_submissions_report ON life_report_submissions(report_id)")


def downgrade():
    op.execute("DROP TABLE life_report_submissions")
