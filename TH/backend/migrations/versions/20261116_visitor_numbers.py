"""Store H5 visitor numbers with their first recorded visit date."""

from alembic import op


revision = "20261116_visitor_numbers"
down_revision = "20261116_postgres"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TABLE landing_visitors (
            owner TEXT PRIMARY KEY,
            region_code TEXT CHECK (region_code ~ '^[A-Z]{2}$'),
            first_visit_date DATE NOT NULL,
            last_visited_at DOUBLE PRECISION NOT NULL,
            serial BIGINT GENERATED ALWAYS AS IDENTITY,
            visitor_number TEXT GENERATED ALWAYS AS (
                COALESCE(region_code, '未知') || '-' ||
                (
                    EXTRACT(YEAR FROM first_visit_date)::integer * 10000
                    + EXTRACT(MONTH FROM first_visit_date)::integer * 100
                    + EXTRACT(DAY FROM first_visit_date)::integer
                )::text || '-' ||
                lpad(serial::text, GREATEST(4, length(serial::text)), '0')
            ) STORED UNIQUE
        )
    """)
    op.execute("CREATE INDEX landing_visitors_last_visit ON landing_visitors(last_visited_at)")
    op.execute("""
        INSERT INTO landing_visitors(owner, first_visit_date, last_visited_at)
        SELECT owner, (to_timestamp(MIN(visited_at)) AT TIME ZONE 'Asia/Shanghai')::date, MAX(visited_at)
        FROM landing_visits
        GROUP BY owner
        ORDER BY MIN(visited_at), owner
    """)


def downgrade():
    op.drop_table("landing_visitors")
