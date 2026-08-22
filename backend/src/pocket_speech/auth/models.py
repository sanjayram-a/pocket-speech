"""Authenticated identity models."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class AuthenticatedUser:
    """Identity derived only from a verified Firebase ID token."""

    firebase_uid: str
    google_subject: str
