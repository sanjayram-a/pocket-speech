from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from pocket_speech.api.dependencies import get_token_verifier
from pocket_speech.app import create_app
from pocket_speech.auth.models import AuthenticatedUser
from pocket_speech.auth.verifier import InvalidCredentialsError, TokenVerifier
from pocket_speech.settings import Settings


class FakeTokenVerifier:
    def verify(self, token: str) -> AuthenticatedUser:
        if token != "valid-test-token":
            raise InvalidCredentialsError
        return AuthenticatedUser(
            firebase_uid="firebase-user-123",
            google_subject="google-subject-456",
        )


@pytest.fixture
def app() -> FastAPI:
    application = create_app(
        Settings(firebase_project_id="test-project"),
        token_verifier=FakeTokenVerifier(),
    )
    application.dependency_overrides[get_token_verifier] = FakeTokenVerifier
    return application


@pytest.fixture
def client(app: FastAPI) -> Iterator[TestClient]:
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def verifier() -> TokenVerifier:
    return FakeTokenVerifier()
