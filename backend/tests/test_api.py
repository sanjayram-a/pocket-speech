from uuid import UUID

from fastapi.testclient import TestClient


def test_health_is_public_and_returns_request_id(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "pocket-speech-backend",
        "version": "0.1.0",
    }
    UUID(response.headers["X-Request-ID"])


def test_authenticated_route_rejects_missing_bearer_token(client: TestClient) -> None:
    response = client.get("/v1/me")

    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.json() == {
        "code": "authentication_failed",
        "message": "Valid authentication is required.",
        "retryable": False,
        "request_id": response.headers["X-Request-ID"],
    }


def test_authenticated_route_rejects_invalid_token(client: TestClient) -> None:
    response = client.get(
        "/v1/usage",
        headers={"Authorization": "Bearer invalid"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "authentication_failed"


def test_me_returns_effective_free_policy_and_zero_usage(client: TestClient) -> None:
    response = client.get(
        "/v1/me",
        headers={"Authorization": "Bearer valid-test-token"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"] == {"firebase_uid": "firebase-user-123"}
    assert body["plan_key"] == "free"
    assert body["policy"] == {
        "plan_key": "free",
        "policy_version": 1,
        "active_voice_limit": 2,
        "monthly_clone_limit": 2,
        "monthly_generation_limit_ms": 600_000,
        "generation_character_limit": 1_000,
        "generation_concurrency_limit": 1,
        "reference_audio_max_bytes": 10 * 1024 * 1024,
        "reference_audio_min_ms": 10_000,
        "reference_audio_max_ms": 30_000,
        "effective_at": "2026-01-01T00:00:00Z",
        "retired_at": None,
    }
    assert body["usage"]["generated_ms"] == 0
    assert body["usage"]["successful_clones"] == 0
    assert body["usage"]["active_voices"] == 0
    assert body["usage"]["active_generations"] == 0


def test_usage_returns_policy_and_zero_usage(client: TestClient) -> None:
    response = client.get(
        "/v1/usage",
        headers={"Authorization": "Bearer valid-test-token"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["policy"]["monthly_generation_limit_ms"] == 600_000
    assert body["usage"]["generated_ms"] == 0
    assert body["usage"]["period_start"].endswith("T00:00:00Z")
    assert body["usage"]["period_end"].endswith("T00:00:00Z")
