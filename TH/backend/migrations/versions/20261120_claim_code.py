"""Give existing and new reports a unique five-digit claim code."""
from alembic import op

revision = "20261120_claim_code"
down_revision = "20261120_line_delivery"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        ALTER TABLE life_reports ADD COLUMN claim_code INTEGER,
            ADD CONSTRAINT life_reports_claim_code_range CHECK (claim_code BETWEEN 10000 AND 99999),
            ADD CONSTRAINT life_reports_claim_code_key UNIQUE (claim_code)
    """)
    op.execute("""
        ALTER TABLE life_reports ALTER COLUMN claim_code SET DEFAULT
            (10000 + (('x' || left(gen_random_uuid()::text, 8))::bit(32)::bigint % 90000))
    """)
    op.execute("""
        DO $$
        DECLARE
            report_row RECORD;
        BEGIN
            FOR report_row IN SELECT id FROM life_reports WHERE claim_code IS NULL LOOP
                FOR attempt IN 1..8 LOOP
                    BEGIN
                        UPDATE life_reports SET claim_code=DEFAULT WHERE id=report_row.id;
                        EXIT;
                    EXCEPTION WHEN unique_violation THEN
                        IF attempt = 8 THEN
                            RAISE;
                        END IF;
                    END;
                END LOOP;
            END LOOP;
        END
        $$
    """)
    op.execute("ALTER TABLE life_reports ALTER COLUMN claim_code SET NOT NULL")


def downgrade():
    op.execute("ALTER TABLE life_reports DROP COLUMN claim_code")
