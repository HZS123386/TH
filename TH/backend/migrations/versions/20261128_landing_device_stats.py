"""Record the device category for H5 visits."""

from alembic import op

revision = "20261128_landing_device_stats"
down_revision = "20261126_tarot_activity"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE landing_visits ADD COLUMN device_type TEXT CHECK (device_type IN ('mobile','desktop'))")


def downgrade():
    op.execute("ALTER TABLE landing_visits DROP COLUMN device_type")
