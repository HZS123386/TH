"""Bind a browser's report owner to an App account."""
from alembic import op

revision = "20261118_h5_app_login"
down_revision = "20261117_preview_queue"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TABLE h5_app_accounts (
            owner TEXT PRIMARY KEY,
            user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE
        );
        CREATE TABLE h5_app_login_codes (
            digest TEXT PRIMARY KEY,
            owner TEXT NOT NULL,
            expires DOUBLE PRECISION NOT NULL,
            active BOOLEAN NOT NULL DEFAULT TRUE
        );
        CREATE UNIQUE INDEX h5_app_login_active_owner ON h5_app_login_codes(owner) WHERE active;
        CREATE INDEX h5_app_login_codes_expires ON h5_app_login_codes(expires);
        CREATE TABLE h5_app_login_key (id INTEGER PRIMARY KEY CHECK (id = 1), secret TEXT NOT NULL);
        INSERT INTO h5_app_login_key VALUES (1, gen_random_uuid()::text || gen_random_uuid()::text);
        CREATE TABLE h5_app_login_failures (
            scope TEXT PRIMARY KEY,
            window_id BIGINT NOT NULL,
            attempts INTEGER NOT NULL
        );
        DROP INDEX life_reports_owner;
        CREATE INDEX life_reports_owner ON life_reports(owner, created, id);
    """)


def downgrade():
    op.execute("""
        DROP TABLE h5_app_login_failures, h5_app_login_key, h5_app_login_codes, h5_app_accounts;
        DROP INDEX life_reports_owner;
        CREATE INDEX life_reports_owner ON life_reports(owner, created);
    """)
