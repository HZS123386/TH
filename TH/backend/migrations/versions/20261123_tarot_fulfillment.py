"""Give Tarot receipts random codes and track manual LINE fulfilment."""

from alembic import op
from sqlalchemy import text

revision = "20261123_tarot_fulfillment"
down_revision = "20261123_tarot_receipts"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE tarot_receipts ALTER COLUMN claim_code DROP IDENTITY")
    op.execute("""
        ALTER TABLE tarot_receipts
            ALTER COLUMN claim_code TYPE TEXT USING 'T-' || claim_code::text,
            ADD COLUMN topic TEXT,
            ADD COLUMN accepted_at DOUBLE PRECISION,
            ADD COLUMN sent_at DOUBLE PRECISION,
            ADD CONSTRAINT tarot_receipt_status_order
                CHECK (sent_at IS NULL OR (accepted_at IS NOT NULL AND sent_at >= accepted_at))
    """)


def downgrade():
    saved = op.get_bind().execute(text("""
        SELECT 1 FROM tarot_receipts
        WHERE topic IS NOT NULL OR accepted_at IS NOT NULL OR sent_at IS NOT NULL LIMIT 1
    """)).first()
    if saved:
        raise RuntimeError("Cannot downgrade without losing Tarot claim codes or fulfilment history.")
    op.execute("""
        ALTER TABLE tarot_receipts
            DROP CONSTRAINT tarot_receipt_status_order,
            DROP COLUMN sent_at,
            DROP COLUMN accepted_at,
            DROP COLUMN topic,
            ALTER COLUMN claim_code TYPE BIGINT USING substring(claim_code from 3)::bigint
    """)
    op.execute("ALTER TABLE tarot_receipts ALTER COLUMN claim_code ADD GENERATED ALWAYS AS IDENTITY (START WITH 100000)")
    op.execute("""
        SELECT setval(pg_get_serial_sequence('tarot_receipts', 'claim_code'),
                      GREATEST(100000, COALESCE(MAX(claim_code) + 1, 100000)), false)
        FROM tarot_receipts
    """)
