"""Join the existing dev schema and the LINE report delivery schema."""

revision = "20261120_merge_line_reports"
down_revision = ("20261119_merge_order_western", "20261120_claim_code")
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
