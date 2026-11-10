from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001_guest_readings"
down_revision = None


def upgrade():
    op.create_table(
        "visits",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("source", sa.String(64), nullable=False),
        sa.Column("campaign", sa.String(64), nullable=False),
        sa.Column("visited_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("submitted_at", sa.DateTime(timezone=True)),
        sa.Column("seen_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_visits_visited_at", "visits", ["visited_at"])
    op.create_table(
        "readings",
        sa.Column("token_hash", sa.String(64), primary_key=True),
        sa.Column("visit_id", sa.String(36), sa.ForeignKey("visits.id", ondelete="SET NULL")),
        sa.Column("status", sa.String(12), nullable=False),
        sa.Column("input", postgresql.JSONB()),
        sa.Column("result", postgresql.JSONB()),
        sa.Column("error", sa.String(40)),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("available_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("lease_until", sa.DateTime(timezone=True)),
        sa.Column("lease_id", sa.String(32)),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_readings_queue", "readings", ["status", "available_at"])
    op.create_index("ix_readings_expires_at", "readings", ["expires_at"])
    op.create_table(
        "rate_limits",
        sa.Column("bucket", sa.String(64), primary_key=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("count", sa.Integer(), nullable=False),
    )
    op.create_index("ix_rate_limits_expires_at", "rate_limits", ["expires_at"])


def downgrade():
    op.drop_table("rate_limits")
    op.drop_table("readings")
    op.drop_table("visits")
