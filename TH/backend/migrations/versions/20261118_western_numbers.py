"""Preserve searchable App report numbers when moving to PostgreSQL."""
from alembic import op

revision = "20261118_western_numbers"
down_revision = "20261118_h5_app_login"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE western_reports ADD COLUMN report_number TEXT")
    op.execute("""
        WITH numbered AS (
            SELECT id, row_number() OVER (ORDER BY started,id) AS number
            FROM western_reports
        )
        UPDATE western_reports AS report
        SET report_number = 'FATE-' || upper(lpad(to_hex(numbered.number), 10, '0'))
        FROM numbered WHERE report.id = numbered.id
    """)
    op.execute("""
        ALTER TABLE western_reports
        ALTER COLUMN report_number SET DEFAULT ('FATE-' || upper(left(replace(gen_random_uuid()::text, '-', ''), 10))),
        ALTER COLUMN report_number SET NOT NULL
    """)
    op.execute("CREATE UNIQUE INDEX western_report_numbers ON western_reports(report_number)")


def downgrade():
    op.execute("ALTER TABLE western_reports DROP COLUMN report_number")
