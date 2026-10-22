from datetime import UTC, datetime, timedelta, timezone

import pytest

from app.database.types import UTCDateTime


def test_database_timestamps_are_normalized_to_utc():
    value = datetime(2026, 10, 20, 18, tzinfo=timezone(timedelta(hours=-5)))
    column = UTCDateTime()
    assert column.process_bind_param(value, None) == datetime(2026, 10, 20, 23, tzinfo=UTC)
    assert column.process_result_value(value, None).tzinfo is UTC


def test_naive_timestamps_are_rejected():
    with pytest.raises(ValueError, match="timezone"):
        UTCDateTime().process_bind_param(datetime(2026, 10, 20), None)
