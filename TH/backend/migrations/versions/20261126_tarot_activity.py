"""Keep Tarot page and interaction statistics separate from astrology visits."""

from alembic import op

revision = "20261126_tarot_activity"
down_revision = "20261126_merge_h5_integrity"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TABLE tarot_activity (
            id UUID PRIMARY KEY,
            visitor_hash TEXT NOT NULL,
            event TEXT NOT NULL,
            visible_ms INTEGER CHECK (visible_ms >= 0),
            recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    op.execute("CREATE INDEX ix_tarot_activity_recorded_at ON tarot_activity (recorded_at)")


def downgrade():
    op.execute("DROP TABLE tarot_activity")
