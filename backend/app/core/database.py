from sqlalchemy.ext.asyncio import (
    create_async_engine,
    async_sessionmaker,
    AsyncSession,
)
from sqlalchemy.pool import NullPool
from sqlalchemy import text
import os


# read the runtime database URL from the environment
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is not set. Check your .env file or environment configuration.")


# create the async SQLAlchemy engine
# - NullPool: required for serverless environments (Vercel)
# - prepared_statement_cache_size=0: required for Supabase transaction pooler
engine = create_async_engine(
    DATABASE_URL,
    poolclass=NullPool,
    connect_args={
        "prepared_statement_cache_size": 0,
        "statement_cache_size": 0,
    },
    echo=False,
)

# create the async session factory
SessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


# FastAPI dependency for getting a DB session.
async def get_db():
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

# simple connectivity check for CCVO-3
async def check_database_connection():
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))