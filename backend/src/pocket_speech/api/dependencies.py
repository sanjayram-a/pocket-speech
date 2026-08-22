"""FastAPI dependency boundaries."""

from typing import Annotated, cast

from fastapi import Depends, Request, Security
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from pocket_speech.api.errors import ApiError
from pocket_speech.auth.models import AuthenticatedUser
from pocket_speech.auth.verifier import (
    InvalidCredentialsError,
    TokenVerifier,
    VerificationUnavailableError,
)
from pocket_speech.repositories.plan_policy import PlanPolicyRepository

bearer_scheme = HTTPBearer(
    auto_error=False,
    bearerFormat="Firebase ID token",
    description="Firebase ID token from a Google-authenticated User.",
)


def get_token_verifier(request: Request) -> TokenVerifier:
    """Return the configured token verifier."""
    return cast("TokenVerifier", request.app.state.token_verifier)


def get_plan_policy_repository(request: Request) -> PlanPolicyRepository:
    """Return the configured Plan Policy repository."""
    return cast(
        "PlanPolicyRepository",
        request.app.state.plan_policy_repository,
    )


def get_authenticated_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Security(bearer_scheme),
    ],
    verifier: Annotated[TokenVerifier, Depends(get_token_verifier)],
) -> AuthenticatedUser:
    """Verify bearer credentials and derive trusted User identity."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        _raise_authentication_failed()
    try:
        return verifier.verify(credentials.credentials)
    except InvalidCredentialsError:
        _raise_authentication_failed()
    except VerificationUnavailableError as error:
        raise ApiError(
            status_code=503,
            code="authentication_unavailable",
            message="Authentication is temporarily unavailable.",
            retryable=True,
        ) from error


def _raise_authentication_failed() -> None:
    raise ApiError(
        status_code=401,
        code="authentication_failed",
        message="Valid authentication is required.",
        retryable=False,
        headers={"WWW-Authenticate": "Bearer"},
    )


AuthenticatedUserDependency = Annotated[
    AuthenticatedUser,
    Depends(get_authenticated_user),
]
PlanPolicyRepositoryDependency = Annotated[
    PlanPolicyRepository,
    Depends(get_plan_policy_repository),
]
