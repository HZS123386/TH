import os
from pathlib import Path

from alembic import context
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import make_url
from sqlalchemy.pool import NullPool


config = context.config
load_dotenv(Path(__file__).resolve().parents[2] / ".env")
url = config.attributes.get("database_url") or os.environ.get("DATABASE_URL", "")
if not url.startswith(("postgresql://", "postgres://")):
    raise RuntimeError("Set DATABASE_URL to the FATE PostgreSQL database.")
database_url = make_url(url).set(drivername="postgresql+psycopg")

if context.is_offline_mode():
    context.configure(dialect_name="postgresql", literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()
else:
    engine = create_engine(database_url, poolclass=NullPool, hide_parameters=True)
    try:
        with engine.connect() as connection:
            context.configure(connection=connection)
            with context.begin_transaction():
                context.run_migrations()
    finally:
        engine.dispose()
