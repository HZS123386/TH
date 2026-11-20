"""Record when a visitor first opens LINE contact for a report."""
from alembic import op

revision = "20261120_line_contact"
down_revision = "20261119_order_attribution"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE life_reports ADD COLUMN line_contact_at DOUBLE PRECISION")
    op.execute("CREATE INDEX life_reports_line_contact_at_idx ON life_reports(line_contact_at DESC, id) "
               "WHERE line_contact_at IS NOT NULL")


def downgrade():
    op.execute("ALTER TABLE life_reports DROP COLUMN line_contact_at")
