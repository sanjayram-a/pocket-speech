from datetime import UTC, datetime, timedelta, timezone

import pytest

from pocket_speech.domain.usage_period import utc_month_period


def test_utc_period_starts_at_month_boundary() -> None:
    instant = datetime(2026, 8, 22, 15, 45, tzinfo=UTC)

    period = utc_month_period(instant)

    assert period.start == datetime(2026, 8, 1, tzinfo=UTC)
    assert period.end == datetime(2026, 9, 1, tzinfo=UTC)


def test_utc_period_handles_year_boundary() -> None:
    period = utc_month_period(datetime(2026, 12, 31, 23, 59, tzinfo=UTC))

    assert period.start == datetime(2026, 12, 1, tzinfo=UTC)
    assert period.end == datetime(2027, 1, 1, tzinfo=UTC)


def test_utc_period_converts_offset_before_selecting_month() -> None:
    local_offset = timezone(timedelta(hours=-5))
    instant = datetime(2026, 1, 31, 20, 0, tzinfo=local_offset)

    period = utc_month_period(instant)

    assert period.start == datetime(2026, 2, 1, tzinfo=UTC)
    assert period.end == datetime(2026, 3, 1, tzinfo=UTC)


def test_utc_period_rejects_naive_timestamp() -> None:
    with pytest.raises(ValueError, match="UTC offset"):
        utc_month_period(datetime(2026, 1, 1))
