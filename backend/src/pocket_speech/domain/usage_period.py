"""UTC calendar-month Usage period calculations."""

from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict

MONTHS_PER_YEAR = 12


class UsagePeriod(BaseModel):
    """A half-open UTC Usage period."""

    model_config = ConfigDict(frozen=True)

    start: datetime
    end: datetime


def utc_month_period(at: datetime) -> UsagePeriod:
    """Return the UTC calendar month containing an aware timestamp."""
    if at.tzinfo is None or at.utcoffset() is None:
        msg = "Usage period timestamps must include a UTC offset."
        raise ValueError(msg)

    current = at.astimezone(UTC)
    start = datetime(current.year, current.month, 1, tzinfo=UTC)
    if current.month == MONTHS_PER_YEAR:
        end = datetime(current.year + 1, 1, 1, tzinfo=UTC)
    else:
        end = datetime(current.year, current.month + 1, 1, tzinfo=UTC)
    return UsagePeriod(start=start, end=end)
