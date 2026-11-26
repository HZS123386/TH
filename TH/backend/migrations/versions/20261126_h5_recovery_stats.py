"""Correlate report lookup misses with a later accepted submission."""

from alembic import op

revision = "20261126_h5_recovery_stats"
down_revision = "20261126_h5_submissions"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE h5_request_failures ADD COLUMN recovery_key BYTEA")
    op.execute("""CREATE INDEX h5_unresolved_lookup ON h5_request_failures(recovery_key)
                  WHERE recovery_key IS NOT NULL AND report_id IS NULL""")


def downgrade():
    op.execute("ALTER TABLE h5_request_failures DROP COLUMN recovery_key")
