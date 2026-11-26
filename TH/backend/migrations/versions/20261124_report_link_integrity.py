"""Keep only live report links active and retain removal history for visits."""

from alembic import op

revision = "20261124_report_link_integrity"
down_revision = "20261120_merge_line_reports"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("SET LOCAL lock_timeout = '5s'")
    op.execute("LOCK TABLE life_reports, landing_visit_reports IN SHARE ROW EXCLUSIVE MODE")
    op.execute("""
        CREATE TABLE landing_visit_report_removals(
            visit_id TEXT NOT NULL REFERENCES landing_visits(id) ON DELETE CASCADE,
            report_id TEXT NOT NULL,
            report_created_at DOUBLE PRECISION,
            removed_at DOUBLE PRECISION,
            PRIMARY KEY(visit_id, report_id)
        )
    """)
    # Older missing reports have no verified removal or creation timestamp.
    op.execute("""
        WITH detached AS (
            DELETE FROM landing_visit_reports l
            WHERE NOT EXISTS (SELECT 1 FROM life_reports r WHERE r.id=l.report_id)
            RETURNING visit_id,report_id
        )
        INSERT INTO landing_visit_report_removals(visit_id,report_id)
        SELECT visit_id,report_id FROM detached
    """)
    op.execute("CREATE INDEX landing_visit_reports_by_report ON landing_visit_reports(report_id)")
    op.execute("""
        ALTER TABLE landing_visit_reports ADD CONSTRAINT landing_visit_reports_report_id_fkey
        FOREIGN KEY(report_id) REFERENCES life_reports(id) ON DELETE CASCADE
    """)
    op.execute("""
        CREATE FUNCTION archive_landing_report_removal() RETURNS TRIGGER
        LANGUAGE plpgsql SET search_path FROM CURRENT AS $$
        BEGIN
            INSERT INTO landing_visit_report_removals(visit_id,report_id,report_created_at,removed_at)
            SELECT v.id,OLD.id,OLD.created,EXTRACT(EPOCH FROM statement_timestamp())
            FROM landing_visit_reports l JOIN landing_visits v ON v.id=l.visit_id
            WHERE l.report_id=OLD.id FOR KEY SHARE OF v
            ON CONFLICT (visit_id,report_id) DO NOTHING;
            RETURN OLD;
        END;
        $$
    """)
    op.execute("""
        CREATE TRIGGER archive_landing_report_removal BEFORE DELETE ON life_reports
        FOR EACH ROW EXECUTE FUNCTION archive_landing_report_removal()
    """)


def downgrade():
    op.execute("DROP TRIGGER archive_landing_report_removal ON life_reports")
    op.execute("DROP FUNCTION archive_landing_report_removal()")
    op.execute("ALTER TABLE landing_visit_reports DROP CONSTRAINT landing_visit_reports_report_id_fkey")
    op.execute("DROP INDEX landing_visit_reports_by_report")
    op.execute("""
        INSERT INTO landing_visit_reports(visit_id,report_id)
        SELECT visit_id,report_id FROM landing_visit_report_removals ON CONFLICT DO NOTHING
    """)
    op.execute("DROP TABLE landing_visit_report_removals")
