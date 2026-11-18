"""Store acknowledged visit events and associate failures without private inputs."""
from alembic import op

revision = "20261117_visit_journey"
down_revision = "20261117_visit_activity"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE landing_visits ADD COLUMN dropped_events INTEGER NOT NULL DEFAULT 0")
    op.execute("""
        CREATE TABLE landing_visit_activity(
            visit_id TEXT NOT NULL REFERENCES landing_visits(id) ON DELETE CASCADE,
            sequence BIGINT NOT NULL,
            page_view_id UUID NOT NULL,
            page TEXT NOT NULL,
            action TEXT NOT NULL,
            state TEXT NOT NULL,
            kind TEXT NOT NULL,
            occurred_at DOUBLE PRECISION NOT NULL,
            received_at DOUBLE PRECISION NOT NULL,
            visible_ms BIGINT NOT NULL CHECK(visible_ms>=0),
            PRIMARY KEY(visit_id,sequence)
        )
    """)
    op.execute("CREATE INDEX landing_activity_page ON landing_visit_activity(visit_id,page_view_id)")
    op.execute("ALTER TABLE h5_request_failures ADD COLUMN owner TEXT, ADD COLUMN visit_id TEXT")
    op.execute("CREATE INDEX h5_failure_visit ON h5_request_failures(visit_id,owner)")


def downgrade():
    op.execute("DROP TABLE landing_visit_activity")
    op.execute("DROP INDEX h5_failure_visit")
    op.execute("ALTER TABLE h5_request_failures DROP COLUMN owner, DROP COLUMN visit_id")
    op.execute("ALTER TABLE landing_visits DROP COLUMN dropped_events")
