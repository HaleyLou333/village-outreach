import subprocess
import sys


def test_migrations_reject_transaction_pooler_without_exposing_credentials(monkeypatch):
    monkeypatch.setenv("MIGRATION_DATABASE_URL", "postgresql://u:hidden-password@localhost:6543/db")
    result = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head", "--sql"],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "transaction pooler" in result.stderr
    assert "hidden-password" not in result.stdout + result.stderr


def test_offline_migration_compiles_without_opening_a_connection(monkeypatch):
    monkeypatch.setenv("MIGRATION_DATABASE_URL", "postgresql://u:hidden-password@localhost:1/db")
    result = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head", "--sql"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "CREATE TABLE app_private.users" in result.stdout
    assert "hidden-password" not in result.stdout + result.stderr
