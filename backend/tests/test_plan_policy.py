from datetime import UTC, datetime, timedelta

import pytest
from pydantic import ValidationError

from pocket_speech.domain.plan_policy import PlanPolicy, free_plan_policy
from pocket_speech.repositories.plan_policy import InMemoryPlanPolicyRepository


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("policy_version", 0),
        ("active_voice_limit", 0),
        ("monthly_clone_limit", -1),
        ("monthly_generation_limit_ms", 0),
        ("generation_character_limit", 0),
        ("generation_concurrency_limit", 0),
        ("reference_audio_max_bytes", 0),
        ("reference_audio_min_ms", 0),
    ],
)
def test_policy_rejects_non_positive_limits(field: str, value: int) -> None:
    values = free_plan_policy().model_dump()
    values[field] = value

    with pytest.raises(ValidationError):
        PlanPolicy.model_validate(values)


def test_policy_rejects_invalid_reference_audio_bounds() -> None:
    values = free_plan_policy().model_dump()
    values["reference_audio_min_ms"] = 30_001

    with pytest.raises(ValidationError):
        PlanPolicy.model_validate(values)


def test_policy_rejects_naive_effective_timestamp() -> None:
    values = free_plan_policy().model_dump()
    values["effective_at"] = datetime(2026, 1, 1)

    with pytest.raises(ValidationError):
        PlanPolicy.model_validate(values)


def test_repository_resolves_latest_effective_version() -> None:
    initial = free_plan_policy()
    later = initial.model_copy(
        update={
            "policy_version": 2,
            "effective_at": initial.effective_at + timedelta(days=30),
        },
    )
    repository = InMemoryPlanPolicyRepository([initial, later])

    resolved = repository.get_effective(
        initial.plan_key,
        datetime(2026, 3, 1, tzinfo=UTC),
    )

    assert resolved.policy_version == 2
