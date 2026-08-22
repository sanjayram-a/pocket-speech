# Pocket Speech Backend

Python 3.12 FastAPI foundation for Pocket Speech. This stage uses Firebase Admin
for identity verification and an in-memory, server-owned Free Plan Policy. It
does not persist Users or Usage and does not run Pocket TTS inference.

## Environment

The service uses Application Default Credentials. No credential files belong in
this repository.

```powershell
$env:POCKET_SPEECH_FIREBASE_PROJECT_ID = "your-firebase-project-id"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
```

Optional settings:

```powershell
$env:POCKET_SPEECH_ENVIRONMENT = "local" # local, staging, or production
$env:POCKET_SPEECH_FIREBASE_CHECK_REVOKED = "true"
```

## Run

```powershell
uv sync
uv run uvicorn pocket_speech.app:create_app --factory --host 127.0.0.1 --port 8000
```

`GET /health` is public. `GET /v1/me` and `GET /v1/usage` require
`Authorization: Bearer <Firebase ID token>`.

## Modal inference

`modal_app.py` defines the private, CPU-only Pocket TTS inference class. It is
not an unauthenticated HTTP API; the authenticated FastAPI routes will invoke
its deployed methods after enforcing policy and ownership.

Deploy the pinned INT8 model directly to production:

```powershell
modal deploy --env production -m pocket_speech.inference.modal_app
```

Run the production cold/warm benchmark only when needed because it starts a
billable container:

```powershell
uv run python -m pocket_speech.inference.benchmark
```

### Production benchmark

Measured on 2026-08-22 using the same voice and text, with one cold request and
20 sequential warm requests per configuration:

| Configuration | Cold client | Warm client p50 / p95 | Warm inference p50 / p95 | Mean RTF | Max RAM | Estimated run cost* |
|---|---:|---:|---:|---:|---:|---:|
| 2 CPU, torchao INT8 | 17.739 s | 3.254 / 3.468 s | 2.728 / 2.884 s | 1.203 | 1049.0 MB | $0.004379 |
| 2 CPU, torch.ao/FBGEMM INT8 | 11.498 s | 1.161 / 1.299 s | 0.614 / 0.673 s | 0.280 | 1147.5 MB | $0.002913 |
| 1 CPU, torch.ao/FBGEMM INT8 | 16.879 s | 1.421 / 1.605 s | 0.807 / 0.976 s | 0.362 | 1153.7 MB | $0.001852 |

`*` Estimated from observed client time plus one 60-second scale-down window at
Modal's listed CPU and memory rates. It excludes image builds and is not an
invoice measurement.

Two-core FBGEMM is the latency candidate: it generated about 3.57 seconds of
audio per inference second and stayed well inside the 2 GB allocation. One-core
FBGEMM is the cost candidate. Keep the benchmark classes at zero minimum
containers until the production choice is finalized.

## Verify

```powershell
uv run ruff check .
uv run ruff format --check .
uv run pytest
```
