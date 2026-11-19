"""Save the visit attribution observed when an H5 payment order is created."""
from alembic import op

revision = "20261119_order_attribution"
down_revision = "20261118_h5_app_login"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        ALTER TABLE life_card_payments
            ADD COLUMN landing_visit_id TEXT,
            ADD COLUMN landing_source TEXT,
            ADD COLUMN landing_campaign TEXT,
            ADD COLUMN landing_region TEXT
    """)


def downgrade():
    op.execute("""
        ALTER TABLE life_card_payments
            DROP COLUMN landing_visit_id,
            DROP COLUMN landing_source,
            DROP COLUMN landing_campaign,
            DROP COLUMN landing_region
    """)
