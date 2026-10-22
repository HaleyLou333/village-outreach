import pytest

from app.database.safety import require_test_database


@pytest.mark.parametrize(
    "url,environment,opt_in",
    [
        (None, "test", True),
        ("postgresql://u:p@127.0.0.1/app_test", "production", True),
        ("postgresql://u:p@127.0.0.1/app_test", "test", False),
        ("postgresql://u:secret@production.example.com/app_test", "test", True),
        ("postgresql://u:p@127.0.0.1/postgres", "test", True),
        ("postgresql://u:p@127.0.0.1/app", "test", True),
        ("postgresql://u:p@localhost.evil.example/app_test", "test", True),
        ("postgresql://u:p@localhost/app_test?host=production.example.com", "test", True),
        ("broken-secret", "test", True),
    ],
)
def test_refuse_unsafe_test_targets(url, environment, opt_in):
    with pytest.raises(ValueError) as error:
        require_test_database(url, environment=environment, opt_in=opt_in)
    assert "secret" not in str(error.value)


def test_allow_explicit_disposable_loopback_database():
    url = require_test_database(
        "postgresql://u:p@127.0.0.1:55439/village_outreach_test",
        environment="test",
        opt_in=True,
    )
    assert url.database == "village_outreach_test"


def test_refuse_database_also_configured_as_runtime(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql://other:password@localhost:55439/app_test")
    with pytest.raises(ValueError):
        require_test_database(
            "postgresql://u:p@localhost:55439/app_test", environment="test", opt_in=True
        )


@pytest.mark.parametrize("key", ["PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS"])
def test_refuse_libpq_connection_overrides(monkeypatch, key):
    monkeypatch.setenv(key, "unexpected-override")
    with pytest.raises(ValueError):
        require_test_database(
            "postgresql://u:p@localhost/app_test", environment="test", opt_in=True
        )
