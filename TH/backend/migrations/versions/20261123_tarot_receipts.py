"""Store explicit LINE receipt requests from the independent Tarot page."""

from alembic import op

revision = "20261123_tarot_receipts"
down_revision = "20261123_h5_code_lookup"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TABLE tarot_receipts (
            request_hash TEXT PRIMARY KEY,
            claim_code BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 100000) UNIQUE,
            report_id TEXT NOT NULL,
            question TEXT NOT NULL,
            spread_id TEXT NOT NULL,
            language TEXT NOT NULL,
            cards JSONB NOT NULL,
            created_at DOUBLE PRECISION NOT NULL DEFAULT EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)
        )
    """)


def downgrade():
    op.execute("DROP TABLE tarot_receipts")
