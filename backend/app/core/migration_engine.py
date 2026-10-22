from sqlalchemy import create_engine, text
import os


# read the migration database URL from the environment
MIGRATION_DATABASE_URL = os.getenv("MIGRATION_DATABASE_URL")

if not MIGRATION_DATABASE_URL:
    raise RuntimeError("MIGRATION_DATABASE_URL environment variable is not set. Check your .env file or environment configuration.")


# create the synchronous SQLAlchemy engine for Alembic
# this MUST use psycopg and MUST NOT use the Supabase transaction pooler, otherwise migrations will fail
engine = create_engine(
    MIGRATION_DATABASE_URL,
    pool_pre_ping=True,
)


# connectivity check for CCVO-3
def check_migration_connection():
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))