"""Firebase bearer-token verification implementations."""

from collections.abc import Mapping, Sequence
from typing import Protocol, cast

import firebase_admin
from firebase_admin import auth, exceptions

from pocket_speech.auth.models import AuthenticatedUser


class InvalidCredentialsError(ValueError):
    """Raised when credentials cannot identify an allowed User."""


class VerificationUnavailableError(RuntimeError):
    """Raised when credentials cannot currently be verified."""


class TokenVerifier(Protocol):
    """Verify bearer tokens and return trusted User identity."""

    def verify(self, token: str) -> AuthenticatedUser:
        """Verify a token without retaining or logging it."""
        ...


class FirebaseTokenVerifier:
    """Verify Firebase ID tokens with Firebase Admin."""

    def __init__(self, project_id: str, *, check_revoked: bool = True) -> None:
        """Configure verification for exactly one Firebase project."""
        app_name = f"pocket-speech-{project_id}"
        try:
            self._app = firebase_admin.get_app(app_name)
        except ValueError:
            self._app = firebase_admin.initialize_app(
                options={"projectId": project_id},
                name=app_name,
            )
        self._check_revoked = check_revoked

    def verify(self, token: str) -> AuthenticatedUser:
        """Verify signature and claims, including revocation and Google identity."""
        try:
            claims = auth.verify_id_token(
                token,
                app=self._app,
                check_revoked=self._check_revoked,
            )
        except auth.CertificateFetchError as error:
            raise VerificationUnavailableError from error
        except (auth.InvalidIdTokenError, ValueError) as error:
            raise InvalidCredentialsError from error
        except exceptions.FirebaseError as error:
            raise VerificationUnavailableError from error
        return _authenticated_user_from_claims(cast("Mapping[str, object]", claims))


def _authenticated_user_from_claims(
    claims: Mapping[str, object],
) -> AuthenticatedUser:
    uid = claims.get("uid")
    firebase = claims.get("firebase")
    if not isinstance(uid, str) or not uid or not isinstance(firebase, Mapping):
        raise InvalidCredentialsError
    if firebase.get("sign_in_provider") != "google.com":
        raise InvalidCredentialsError

    identities = firebase.get("identities")
    if not isinstance(identities, Mapping):
        raise InvalidCredentialsError
    google_identities = identities.get("google.com")
    if (
        not isinstance(google_identities, Sequence)
        or isinstance(google_identities, str)
        or not google_identities
        or not isinstance(google_identities[0], str)
        or not google_identities[0]
    ):
        raise InvalidCredentialsError
    return AuthenticatedUser(firebase_uid=uid, google_subject=google_identities[0])
