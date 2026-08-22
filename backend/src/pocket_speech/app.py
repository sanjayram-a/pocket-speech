"""FastAPI application factory."""

from fastapi import FastAPI

from pocket_speech import __version__
from pocket_speech.api.errors import install_error_handlers
from pocket_speech.api.request_id import install_request_id_middleware
from pocket_speech.api.routes import health_router, v1_router
from pocket_speech.auth.verifier import FirebaseTokenVerifier, TokenVerifier
from pocket_speech.domain.plan_policy import free_plan_policy
from pocket_speech.repositories.plan_policy import (
    InMemoryPlanPolicyRepository,
    PlanPolicyRepository,
)
from pocket_speech.settings import Settings


def create_app(
    settings: Settings | None = None,
    *,
    token_verifier: TokenVerifier | None = None,
    plan_policy_repository: PlanPolicyRepository | None = None,
) -> FastAPI:
    """Build an application with replaceable infrastructure boundaries."""
    resolved_settings = settings or Settings()  # type: ignore[call-arg]
    app = FastAPI(
        title="Pocket Speech API",
        version=__version__,
        docs_url="/docs" if resolved_settings.environment != "production" else None,
        redoc_url=None,
    )
    app.state.settings = resolved_settings
    app.state.token_verifier = token_verifier or FirebaseTokenVerifier(
        resolved_settings.firebase_project_id,
        check_revoked=resolved_settings.firebase_check_revoked,
    )
    app.state.plan_policy_repository = (
        plan_policy_repository or InMemoryPlanPolicyRepository([free_plan_policy()])
    )

    install_error_handlers(app)
    install_request_id_middleware(app)
    app.include_router(health_router)
    app.include_router(v1_router)
    return app
