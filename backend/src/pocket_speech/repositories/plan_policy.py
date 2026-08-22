"""Plan Policy repository boundary."""

from collections.abc import Iterable
from datetime import UTC, datetime
from typing import Protocol

from pocket_speech.domain.plan_policy import PlanKey, PlanPolicy


class PlanPolicyNotFoundError(LookupError):
    """Raised when no Plan Policy is effective at the requested time."""


class PlanPolicyRepository(Protocol):
    """Resolve immutable Plan Policy snapshots."""

    def get_effective(self, plan_key: PlanKey, at: datetime) -> PlanPolicy:
        """Return the policy effective for a plan at the supplied instant."""
        ...


class InMemoryPlanPolicyRepository:
    """Validated in-memory repository for startup and isolated tests."""

    def __init__(self, policies: Iterable[PlanPolicy]) -> None:
        """Store policies after rejecting duplicate versions."""
        by_identity: dict[tuple[PlanKey, int], PlanPolicy] = {}
        for policy in policies:
            identity = (policy.plan_key, policy.policy_version)
            if identity in by_identity:
                msg = f"Duplicate Plan Policy: {identity[0]} v{identity[1]}"
                raise ValueError(msg)
            by_identity[identity] = policy
        self._policies = tuple(by_identity.values())

    def get_effective(self, plan_key: PlanKey, at: datetime) -> PlanPolicy:
        """Return the latest policy active at an aware instant."""
        if at.tzinfo is None or at.utcoffset() is None:
            msg = "Policy resolution timestamps must include a UTC offset."
            raise ValueError(msg)
        instant = at.astimezone(UTC)
        candidates = [
            policy
            for policy in self._policies
            if policy.plan_key == plan_key
            and policy.effective_at <= instant
            and (policy.retired_at is None or instant < policy.retired_at)
        ]
        if not candidates:
            msg = f"No effective Plan Policy for {plan_key}."
            raise PlanPolicyNotFoundError(msg)
        return max(candidates, key=lambda policy: policy.policy_version)
