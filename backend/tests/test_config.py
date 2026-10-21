import pytest
from sqlalchemy.pool import NullPool

from app.core.config import Settings
from app.database.session import build_engine, postgres_url


def test_settings_import_and_no_credentials_required_for_health():
    settings = Settings(_env_file=None)
    assert settings.app_name == "CCVO Backend"
    assert settings.database_url is None


def test_settings_redact_database_credentials():
    settings = Settings(
        _env_file=None,
        database_url="postgresql://owner:super-secret@localhost/example",
        migration_database_url="postgresql://owner:another-secret@localhost/example",
    )
    assert "super-secret" not in repr(settings)
    assert "another-secret" not in repr(settings)


@pytest.mark.parametrize("prefix", ["postgres", "postgresql", "postgresql+psycopg"])
def test_postgres_driver_normalization(prefix):
    url = postgres_url(f"{prefix}://owner:password@localhost/example")
    assert url.drivername == "postgresql+psycopg"


@pytest.mark.parametrize("value", ["broken-secret", "sqlite:///file.db", "postgresql:///"])
def test_invalid_connection_settings_do_not_echo_input(value):
    with pytest.raises(ValueError) as error:
        postgres_url(value)
    assert value not in str(error.value)


def test_engine_uses_external_pooler_without_a_second_pool():
    engine = build_engine("postgresql://owner:secret@localhost/example")
    try:
        assert isinstance(engine.pool, NullPool)
        _, options = engine.dialect.create_connect_args(engine.url)
        assert options["dbname"] == "example"
    finally:
        engine.dispose()
