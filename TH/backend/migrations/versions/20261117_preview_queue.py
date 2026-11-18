"""Keep preview work recoverable across requests and service restarts."""
from alembic import op

revision = "20261117_preview_queue"
down_revision = "20261117_visit_journey"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE life_reports ADD COLUMN preview_network TEXT NOT NULL DEFAULT ''")
    op.execute("CREATE INDEX life_preview_queue ON life_reports(preview_state,lease_until,created,id)")


def downgrade():
    op.execute("DROP INDEX life_preview_queue")
    op.execute("ALTER TABLE life_reports DROP COLUMN preview_network")
