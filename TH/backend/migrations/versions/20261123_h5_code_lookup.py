"""Record the report from which each H5 App login code was issued."""

from alembic import op

revision = "20261123_h5_code_lookup"
down_revision = "20261121_merge_h_jy"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE h5_app_login_codes ADD COLUMN report_id TEXT")


def downgrade():
    op.execute("ALTER TABLE h5_app_login_codes DROP COLUMN report_id")
