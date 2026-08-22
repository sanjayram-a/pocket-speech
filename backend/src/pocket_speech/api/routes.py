"""Initial health, User, and Usage routes."""

from datetime import UTC, datetime

from fastapi import APIRouter

from pocket_speech import __version__
from pocket_speech.api.dependencies import (
    AuthenticatedUserDependency,
    PlanPolicyRepositoryDependency,
)
from pocket_speech.api.errors import ErrorResponse
from pocket_speech.api.models import (
    HealthResponse,
    MeResponse,
    UsageResponse,
    UsageSnapshotResponse,
    UserIdentityResponse,
)
from pocket_speech.domain.plan_policy import PlanKey
from pocket_speech.domain.usage_period import utc_month_period

health_router = APIRouter()
v1_router = APIRouter(prefix="/v1")

AUTH_RESPONSES = {
    401: {"model": ErrorResponse, "description": "Authentication failed."},
    503: {"model": ErrorResponse, "description": "Service temporarily unavailable."},
}


@health_router.get("/health", tags=["health"])
def health() -> HealthResponse:
    """Report process liveness without requiring external dependencies."""
    return HealthResponse(
        status="ok",
        service="pocket-speech-backend",
        version=__version__,
    )


@v1_router.get("/me", responses=AUTH_RESPONSES, tags=["user"])
def me(
    user: AuthenticatedUserDependency,
    policies: PlanPolicyRepositoryDependency,
) -> MeResponse:
    """Return verified identity and current non-persisted Free state."""
    now = datetime.now(UTC)
    policy = policies.get_effective(PlanKey.FREE, now)
    return MeResponse(
        user=UserIdentityResponse(firebase_uid=user.firebase_uid),
        plan_key=policy.plan_key,
        policy=policy,
        usage=_zero_usage(now),
    )


@v1_router.get(
    "/usage",
    responses=AUTH_RESPONSES,
    tags=["usage"],
)
def usage(
    _user: AuthenticatedUserDependency,
    policies: PlanPolicyRepositoryDependency,
) -> UsageResponse:
    """Return the effective policy and zero counters until persistence lands."""
    now = datetime.now(UTC)
    policy = policies.get_effective(PlanKey.FREE, now)
    return UsageResponse(
        plan_key=policy.plan_key,
        policy=policy,
        usage=_zero_usage(now),
    )


def _zero_usage(at: datetime) -> UsageSnapshotResponse:
    period = utc_month_period(at)
    return UsageSnapshotResponse(
        period_start=period.start,
        period_end=period.end,
        generated_ms=0,
        successful_clones=0,
        active_voices=0,
        active_generations=0,
    )
