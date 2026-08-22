# Pocket Speech MVP Implementation Plan

Status: planning only. No application or backend implementation has started.

## 1. Release Goal

Ship an Android-first Flutter app in which a Google-authenticated user can:

1. Record a consented English reference sample.
2. Create and retain up to two Voice Profiles on-device, subject to two successful clone creations per UTC month.
3. Generate MP3 speech from up to 1,000 characters using a local Voice Profile.
4. Play, rename, share, and delete generated audio on-device.
5. Complete mobile-first onboarding with mandatory Google sign-in and an optional Pro preview that can be skipped.
6. See server-enforced monthly Usage, clone, and active-voice limits.
7. Choose an MP3 export location and system-default, light, or dark appearance in Settings.
8. Clear local content without losing identity, Usage, Clone Allowance, or future purchase state.
9. Delete the account through a separate compliance flow.

The backend temporarily processes reference recordings, Voice Profiles, text, and generated audio. It permanently stores none of those payloads.

## 2. Resolved Decisions

| Area | MVP decision |
|---|---|
| Platform | Android, Flutter, Dart null safety |
| Repository | Monorepo with `app/`, `backend/`, and root `docs/` |
| Authentication | Mandatory Google sign-in through Firebase Authentication |
| App state | Riverpod 3; framework-free repositories and domain models |
| Local metadata | Drift on SQLite |
| Inference | Kyutai Pocket TTS on Modal, CPU-first and quantized if the spike validates it |
| Language | English only |
| Reference input | In-app mono WAV, 10-30 seconds, maximum 10 MB |
| Consent | Explicit attestation plus a spoken consent phrase; no audio import |
| Voice Profile | Local `.safetensors` plus a signed manifest |
| Generation output | Completed MP3 response, not streaming |
| Free plan | 2 active Voice Profiles, 2 successful clone creations per UTC month, 600 generated seconds per UTC month, 1 active Generation, 1,000 characters per request |
| Clone deletion | Frees an active slot but never refunds monthly Clone Allowance |
| Limit source | Versioned server-owned Plan Policy; the app displays but never defines effective limits |
| Future paid cap | 2,000 characters; billing remains outside MVP |
| Quota edge | A request started below quota may finish above it; charge full duration and reject later requests |
| Usage charge point | Charge when server-side generation completes, even if delivery later fails |
| Text retention | Do not retain generated input text locally or on the backend |
| Content clearing | Remove local content and deactivate server voice metadata; retain User, Usage, Clone Allowance, plan, and purchase history |
| Account deletion | Separate compliance flow with narrowly scoped anti-reset/purchase retention where legally permitted |
| Theme | One global Material 3 design system with system-default, light, and dark modes |
| Visual direction | Warm editorial audio-tool UI inspired by the provided recording/settings reference; subscription hierarchy inspired by the provided plan cards without copying their neon palette |
| Download location | User-selected Android export directory; canonical audio and Voice Profiles remain app-private |
| Performance | Mobile-first responsive layouts and profiled, reduced-motion-aware animations with no known release-blocking jank |

## 3. System Shape

```text
Flutter app
  |-- Firebase Authentication (Google provider only)
  |-- Drift + app-local filesystem
  `-- HTTPS with Firebase ID token
        |
        v
Modal FastAPI service
  |-- Firebase Admin token verification
  |-- Pocket TTS model lifecycle and temporary inference files
  |-- Voice Profile manifest signing and verification
  `-- Neon PostgreSQL
        |-- users, Plan Policies, and future entitlements
        |-- active voice metadata
        |-- generation and clone usage periods
        |-- generation metadata
        `-- idempotency and concurrency leases
```

Trust rules:

- The Firebase token is the only source of user identity.
- Client-supplied user IDs, plan names, Usage, duration, and subscription state are ignored.
- The server decodes media and checks actual content; extensions and MIME headers are not trusted.
- Voice Profile bytes are accepted only when their hash matches a valid signed manifest owned by the authenticated User and an active Neon row.
- Secrets, tokens, text, audio, and Voice Profile bytes never enter logs or error telemetry.

## 4. Repository Layout

```text
PockitSpeech/
|-- AGENTS.md
|-- CONTEXT.md
|-- app/
|   |-- android/
|   |-- lib/
|   |   |-- app/                 # bootstrap, routing, theme
|   |   |-- core/                # errors, HTTP, persistence primitives
|   |   `-- features/
|   |       |-- onboarding/
|   |       |-- auth/
|   |       |-- voices/
|   |       |-- generation/
|   |       |-- history/
|   |       |-- usage/
|   |       |-- subscription/
|   |       `-- settings/
|   |-- test/
|   `-- integration_test/
|-- backend/
|   |-- src/pocket_speech/
|   |   |-- api/
|   |   |-- auth/
|   |   |-- db/
|   |   |-- inference/
|   |   |-- services/
|   |   `-- settings.py
|   |-- migrations/
|   `-- tests/
|-- contracts/
|   |-- openapi.json
|   `-- fixtures/
`-- docs/
    |-- adr/
    |-- design-direction.md
    `-- implementation-plan.md
```

Within each Flutter feature, add `presentation`, `application`, `domain`, and `data` folders only when the feature has logic at that boundary. Do not create empty ceremonial layers.

## 5. Flutter Design

### 5.1 Bootstrap and Navigation

- Initialize Firebase, local storage, Drift, and the API client before rendering product routes.
- Show a recoverable startup failure screen if local initialization fails.
- Gate every product route behind Firebase authentication.
- On first launch, present concise value, local-storage/privacy, and consent onboarding before a mandatory `Continue with Google` action.
- Treat Google authentication as both sign-up and sign-in; it cannot be skipped.
- After first successful authentication, show a Pro subscription preview with a visible Skip action. Billing is not active in MVP, so plan CTAs are marked `Coming soon` and cannot fabricate a purchase.
- Persist onboarding-policy version per User, allow replay from Settings, and show onboarding again only when a material consent/privacy version requires it.
- Scope all local files and queries to the authenticated Firebase UID so switching Google accounts cannot expose another User's content.
- Use phone-first layouts that remain usable from 320dp width through large Android phones, under display cutouts, keyboard insets, and large text.

Primary destinations:

- Generate
- Voices
- History
- Usage and Settings

### 5.2 State and Dependencies

- Use Riverpod providers for dependency wiring and feature controllers.
- Use immutable sealed states when an operation needs explicit `idle`, `loading`, `success`, and `failure` states.
- Keep authentication, repositories, storage, recording, playback, and API clients behind narrow interfaces.
- Keep Drift rows and HTTP DTOs out of widgets.
- Map all transport, authentication, storage, decoding, quota, and concurrency errors into typed application failures.
- Disable duplicate submit actions while cloning or generating, but still rely on server idempotency and concurrency enforcement.

Expected package categories, validated at scaffold time:

- Firebase Core and Authentication with Google sign-in
- Riverpod 3
- Drift/SQLite
- Dio or an equivalent multipart-capable HTTP client
- In-app PCM WAV recording and audio-session coordination
- MP3 playback
- App-directory discovery, Android Storage Access Framework directory selection, persisted URI access, and native share sheet
- UUID generation and cryptographic hashing

Do not add file picking, cloud storage, billing, analytics SDKs, or background job packages.

### 5.3 Local Storage

Use an identity-scoped support directory:

```text
users/<sha256-firebase-uid>/
|-- voices/<voice-id>/state.safetensors
|-- voices/<voice-id>/manifest.jws
|-- generations/<generation-id>.mp3
`-- temp/
```

Drift tables:

`voice_profiles`

- `id`
- `owner_key`
- `name`
- `language`
- `state_path`
- `manifest_path`
- `created_at`
- `deletion_state`

`generations`

- `id`
- `owner_key`
- `voice_profile_id` nullable after profile deletion
- `title`
- `audio_path`
- `duration_ms`
- `size_bytes`
- `created_at`

`pending_operations`

- `id`
- `owner_key`
- `kind`
- `entity_id`
- `request_id`
- `attempt_count`
- `last_error_code`
- `updated_at`

`user_preferences`

- `owner_key`
- `onboarding_policy_version`
- `theme_mode` (`system`, `light`, `dark`)
- `export_tree_uri` nullable
- `updated_at`

Do not store input text. Default Generation titles should be neutral and sequential, not derived from the text.

The app-private Generation file remains the canonical copy. A configured download location is an Android document-tree URI used only when exporting/copying MP3 files. Voice Profiles, manifests, Drift files, and temporary recordings never move to public or user-selected storage. If persisted directory permission is revoked, preserve the canonical file and ask the User to select a destination again.

Filesystem consistency protocol:

1. Write downloads to `temp/` with a unique name.
2. Flush, validate content type, size, and checksum, then atomically rename into its final path.
3. Insert the Drift row only after the final file exists.
4. If the database write fails, remove the final file or leave it for startup reconciliation.
5. On startup, remove stale temp files, detect missing referenced files, and remove unreferenced files after a safe age threshold.
6. For deletion, hide the item and delete its local file first. Retain a pending server cleanup operation until server metadata is deactivated.

### 5.4 Feature Flows

Google sign-in:

1. Complete Google sign-in through Firebase Authentication.
2. Obtain a fresh Firebase ID token for API calls; do not persist or log token strings manually.
3. Call `GET /v1/me` to create or load the backend User and current limits.
4. Open only the matching identity-scoped local store.

Voice cloning:

1. Show privacy terms, explicit ownership attestation, and the spoken consent phrase.
2. Request microphone permission in context and explain denial recovery.
3. Record 10-30 seconds as lossless WAV; show level, elapsed time, minimum/maximum bounds, playback, retake, and delete controls.
4. Show both active Voice Profile capacity and monthly Clone Allowance before submission.
5. Create and persist an idempotency request ID before upload.
6. Temporarily upload only that in-app WAV, with consent version and authenticated token, to Modal for `.safetensors` creation.
7. Count one successful monthly clone when the server activates the generated Voice Profile. Cancellation or failure before activation does not count; interrupted delivery after activation does count.
8. Save returned `.safetensors` and signed manifest through the filesystem consistency protocol.
9. If local persistence fails, immediately request server deactivation; keep a repair operation if that call fails. Deactivation frees the active slot but does not refund Clone Allowance.
10. Always delete the temporary WAV after success, cancellation, or failure; Modal also removes every request file after processing.

Generation:

1. Require 1-1,000 non-whitespace Unicode characters and an active local Voice Profile.
2. Keep text only in controller memory for the current composition.
3. Persist an idempotency request ID, then upload text, profile bytes, signed manifest, and voice ID.
4. Receive one completed MP3 with generation ID, duration, and checksum response metadata.
5. Persist the MP3 atomically, then add local metadata and clear the text field only after success.
6. If the connection becomes ambiguous after submission, explain that server-completed audio may have consumed Usage before allowing a new request ID.

Playback and history:

- Permit one playback session at a time and release audio resources on route/app lifecycle changes.
- Support play, pause, seek, rename, share, and delete.
- Share through a temporary content URI and never broaden filesystem permissions.
- Keep a Generation playable after its Voice Profile is deleted.

Clear Content:

- Confirm the irreversible loss of local Voice Profiles and audio.
- Delete local sensitive files promptly.
- Bulk-deactivate active server voice rows so slots are released.
- Retain Usage, Clone Allowance consumed in the current period, plan, generation metadata, and future purchase history in Neon.
- Surface pending server cleanup until retries succeed.

Delete Account:

- Require recent Firebase reauthentication and an explicit destructive confirmation.
- Delete or anonymize backend personal records first, then delete the Firebase account and local files.
- Retain only data justified for current-period quota-reset prevention, fraud prevention, financial records, or legal obligations.
- Document the retained fields and expiry in the privacy policy before release.

### 5.5 Global Design System

Detailed visual tokens and screen direction live in [`design-direction.md`](./design-direction.md).

Use one `AppTheme` entry point to build `ThemeData`, `ColorScheme`, typography, component themes, shape tokens, spacing tokens, elevation, and motion durations. Feature widgets consume semantic theme values and must not define ad hoc presentation colors.

Theme behavior:

- Default to `ThemeMode.system` on first launch.
- Allow `system`, `light`, and `dark` selection in Settings and persist it locally.
- Apply theme changes immediately throughout onboarding, subscription, recording, generation, history, and settings routes.
- Maintain AA contrast for normal text and visible focus/pressed/disabled states.
- Golden-test both brightness modes, not just recolored screenshots.

Visual direction from the provided recording/settings reference:

- Warm off-white light background, white elevated cards, near-black text/actions, and a restrained coral-orange accent.
- A purpose-designed dark theme using near-black surfaces and adjusted semantic accent/contrast values, not a simple color inversion.
- Large waveform/timer focal points for recording, compact rounded cards for history and usage, generous whitespace, soft elevation, and pill-shaped primary controls.
- A compact bottom navigation treatment inspired by the reference while preserving Android navigation insets and 48dp targets.
- Use the reference for hierarchy and tone only. Do not copy its brand, logo, text, exact screens, or decorative assets.

Subscription-screen direction from the provided plan-card reference:

- Reuse its clear plan title, price/availability area, feature checklist, emphasized CTA area, and compact top navigation hierarchy.
- Do not use or copy its neon yellow/green palette. Use Pocket Speech's global semantic colors in both light and dark modes.
- MVP shows a truthful Pro preview with `Coming soon` and a prominent Skip action. When billing ships, prices and offers come from Google Play rather than hard-coded UI strings.

### 5.6 Settings

The Settings screen contains:

- Usage card: generated seconds used/limit, successful clones used/limit, active voices used/limit, and next UTC reset date.
- Pro subscription row/card: opens the subscription screen; MVP displays `Coming soon`, while future builds show server-verified entitlement and restore/manage actions.
- Download location: select, display, test, change, or clear an Android document-tree export destination.
- Appearance: system default, light, or dark.
- Replay onboarding.
- Privacy and temporary-processing summary.
- Clear Content, sign out, and Delete Account actions with distinct consequences.
- App version and model version information.

Settings must remain useful offline for local preferences and content actions. Quota and subscription sections display the last verified server snapshot with a visible stale/offline state rather than inventing current values.

### 5.7 Mobile Performance and Motion

- Prefer implicit animations and narrowly scoped `AnimatedWidget`/transition widgets; do not rebuild whole screens on every animation tick.
- Isolate waveform painting and frequently changing recording indicators with `CustomPainter` and `RepaintBoundary` where profiling proves useful.
- Avoid expensive clipping, blur, opacity layers, oversized images, and uncontrolled shadows in scrolling lists.
- Virtualize History and Voices lists and keep synchronous file hashing, decoding, and database work off the UI isolate when measurements show frame impact.
- Pause waveform/ambient animation when routes are hidden or the app is backgrounded.
- Respect Android animator/reduced-motion accessibility settings by removing decorative motion and shortening essential transitions.
- Define one global motion scale and standard durations; avoid feature-specific animation constants.
- Profile in Flutter profile mode on physical low/mid-range Android hardware at 60Hz and a representative 120Hz device.
- Treat repeatable build/raster frame misses, scrolling hitching, excessive shader work, and memory growth as release blockers. Record DevTools frame traces for onboarding, recording, history scrolling, theme switching, and subscription transitions.

## 6. Backend Design

### 6.1 Service Lifecycle

- Build one version-pinned Modal image for FastAPI, Pocket TTS, CPU PyTorch, audio decoding, and MP3 encoding.
- Load one English Pocket TTS model per warm container during container startup.
- Begin with one inference at a time per model instance; scale horizontally within a conservative container cap.
- Enable CPU quantization only if the inference spike confirms quality, compatibility, latency, and memory improvements.
- Use temporary directories for every request and remove them in `finally` blocks.
- Disable request-body logging, access-query logging, model prompt logging, and exception dumps containing payloads.

### 6.2 Neon Schema

Store duration as integer milliseconds, not floating point seconds.

`plan_policies`

- `plan_key` (`free`, future `pro_monthly`, future `pro_yearly`)
- `policy_version`
- `active_voice_limit`
- `monthly_clone_limit`
- `monthly_generation_limit_ms`
- `generation_character_limit`
- `generation_concurrency_limit`
- `reference_audio_max_bytes`
- `reference_audio_min_ms`
- `reference_audio_max_ms`
- `effective_at`
- `retired_at` nullable
- `updated_at`
- composite primary key on plan key and policy version

Seed Free policy through a migration, but read effective limits through one backend policy service. Policy changes are validated, audited, and applied without a Flutter release. Resolve one immutable policy snapshot at request start so mid-request edits cannot produce inconsistent enforcement.

`users`

- `id` UUID primary key
- `firebase_uid` unique
- `google_identity_hash` unique keyed HMAC, never raw Google subject
- `plan_key` server-owned key, initially `free`
- `created_at`
- `deleted_at` nullable

`voice_profiles`

- `id` UUID primary key
- `user_id` foreign key
- `status` (`pending`, `active`, `deleted`)
- `state_sha256`
- `model_version`
- `consent_version`
- `clone_request_id` unique per User
- `clone_period_start`
- `reservation_expires_at` nullable
- `created_at`
- `deleted_at` nullable

`usage_periods`

- `user_id`
- `period_start` UTC date
- `generated_ms`
- `successful_clones`
- composite primary key on user and period

`generation_requests`

- `request_id` UUID
- `user_id`
- `status` (`pending`, `succeeded`, `failed`)
- `generation_id` nullable
- `usage_period_start`
- `started_at`
- `completed_at` nullable
- unique on user and request ID

`generation_leases`

- `user_id` primary key
- `request_id`
- `expires_at`

`generations`

- `id` UUID primary key
- `user_id`
- `voice_profile_id`
- `request_id` unique
- `character_count`
- `duration_ms`
- `created_at`

`identity_tombstones`

- keyed identity HMAC
- minimum quota/fraud-prevention state
- explicit expiry and retention reason

Use database constraints and transactions for ownership, active voice count, monthly successful clone count, request idempotency, Usage updates, and lease acquisition. Do not rely on in-process locks because Modal can run multiple containers. The Flutter app never hard-codes quota values as authority; it renders the effective Plan Policy returned by FastAPI.

### 6.3 Authentication

- Accept only `Authorization: Bearer <Firebase ID token>`.
- Verify signature, issuer, audience, expiry, revocation policy, and Firebase project.
- Derive the Firebase UID and Google provider identity from verified claims.
- Map identity to an internal User; never use email as the key.
- Return `401` for invalid/expired credentials and let Flutter refresh once before requiring sign-in.
- Rate-limit authentication failures and malformed requests without logging tokens or request bodies.

### 6.4 Signed Voice Manifest

The server creates a compact signed manifest containing:

- manifest version
- key ID
- internal user ID
- voice ID
- Pocket TTS model version
- SHA-256 of exact `.safetensors` bytes
- creation timestamp

Use an Ed25519 signing key held in Modal secrets and support verification-key rotation by key ID. The client stores the manifest as an opaque sidecar. On Generation, the backend verifies signature, owner, model compatibility, active voice row, byte size, and a constant-time hash comparison before loading the state.

### 6.5 HTTP Contract

All endpoints are under `/v1`. FastAPI OpenAPI is checked into `contracts/openapi.json`; Flutter DTO tests consume shared success and error fixtures.

`GET /v1/me`

- Creates or returns the authenticated User.
- Returns plan, effective Plan Policy, current Usage and Clone Allowance, reset date, and policy versions.

`GET /v1/usage`

- Returns period start/end, generated/limit milliseconds, successful/limit clone counts, active voice count/limit, character limit, and active-generation state.

`GET /v1/voices`

- Returns active server voice IDs and creation dates only.
- Supports reconciliation of server rows that have no local file.

`POST /v1/voices/clone`

- Multipart WAV plus request ID and consent-policy version.
- Returns voice-state bytes with voice ID, signed manifest, state hash, and model version as bounded response metadata.

`DELETE /v1/voices/{voice_id}`

- Idempotently deactivates an owned profile and frees its active slot without refunding monthly Clone Allowance.

`POST /v1/generate`

- Multipart text, voice ID, signed manifest, Voice Profile bytes, and request ID.
- Returns `audio/mpeg` with generation ID, duration milliseconds, and checksum metadata.

`DELETE /v1/content`

- Idempotently deactivates all active Voice Profiles while preserving User, Usage, and plan records.

`DELETE /v1/me`

- Performs the backend portion of account deletion after recent-auth proof.

Error body:

```json
{
  "code": "quota_exhausted",
  "message": "Monthly generation allowance is exhausted.",
  "retryable": false,
  "request_id": "uuid"
}
```

Stable error codes include authentication failure, consent required, invalid media, request too large, character limit, active voice limit, monthly clone limit, generation quota exhausted, generation already active, unknown/inactive voice, invalid manifest, incompatible model, idempotency conflict, inference failure, and temporary service failure.

### 6.6 Clone Transaction

1. Authenticate, resolve the User's Plan Policy snapshot, and validate body size before decoding.
2. Decode and validate WAV duration and audio properties.
3. In one transaction, lock the User and current UTC usage-period rows, clear expired pending reservations, enforce both active/pending voice capacity and successful-plus-pending monthly Clone Allowance, and idempotently insert a pending voice row keyed by clone request ID and period.
4. Create the Pocket TTS state in a request-scoped temporary directory.
5. Serialize state, calculate SHA-256, create the signed manifest, and prepare bounded response metadata.
6. In one transaction, mark the voice row active and increment `successful_clones` only after all output artifacts are valid.
7. Return bytes and delete the reference/output temp files after response handling.
8. On failure, mark/delete the pending row so it does not consume a slot. An expiry recovers a reservation after container death.

If a replayed clone request ID is already active, return an `idempotency_already_completed` response because the bytes cannot be redelivered. `GET /v1/voices` then lets the app identify and deactivate the server-only profile. No backend Voice Profile bytes are retained for redelivery. Deletion never decrements `successful_clones`; the counter resets only by selecting the next UTC usage period.

### 6.7 Generation Transaction

1. Authenticate, resolve the User's Plan Policy snapshot, and validate text length, multipart sizes, and request ID against that policy.
2. In one transaction, create/lock the User's request-start UTC usage-period row, reject only when generated duration is already at or above the policy limit, and acquire the idempotency row and per-User generation lease.
3. Record the request-start period on the request so a Generation crossing midnight is charged to the period in which it started.
4. Set lease expiry beyond the hard inference timeout plus cleanup margin, or renew it while inference remains healthy.
5. Verify the signed manifest, ownership, active voice row, model version, and state hash.
6. Generate PCM, enforce a server safety timeout/output ceiling, encode MP3, and calculate duration from sample count.
7. In one transaction, insert Generation metadata, increment Usage by full duration, mark the request succeeded, and release the lease.
8. Return MP3 bytes, then remove all temporary files.
9. On pre-commit failure, mark the request failed and release the lease. Expiring leases recover crashed containers.

A replayed succeeded request ID must never generate or charge again. Because audio is not retained, return a specific `idempotency_already_completed` response rather than pretending the original MP3 can be redelivered.

### 6.8 Future Google Play Subscriptions

Billing remains disabled in MVP, but the boundary is planned now:

- Flutter will use Google Play Billing through a maintained Flutter plugin and render localized products, base plans, offers, and prices returned by Google Play. Never hard-code purchasable prices.
- Flutter sends the purchase token and product identifier to an authenticated FastAPI verification endpoint; it never directly sets `plan` or entitlement fields.
- FastAPI verifies that the purchase is in the purchased state through the Google Play Developer API, binds it to the User, grants the matching server Plan Policy, and acknowledges the purchase from the backend.
- Pending, canceled, grace-period, hold, expired, replaced, restored, and resubscribed states are modeled explicitly before launch.
- A future `subscriptions` table stores the User, product/base-plan identifiers, protected purchase token, state, entitlement expiry, acknowledgement state, latest order reference, and verification timestamps.
- Real-time Developer Notifications through Google Cloud Pub/Sub reconcile renewals and revocations when billing ships. Pub/Sub is future billing infrastructure and remains outside MVP.
- Settings and `/v1/me` display only server-verified entitlement state. Restore purchases triggers backend verification rather than trusting local purchase history.

## 7. Delivery Phases

### Phase 0: Inference and Audio Spike

- Pin a Pocket TTS release and model artifact.
- Benchmark cold start, warm latency, real-time factor, memory, output quality, and quantization on the intended Modal CPU.
- Validate 10-30 second mono WAV capture settings against clone quality.
- Validate `.safetensors` export/import and deterministic byte hashing.
- Select MP3 bitrate using listening tests and measured file sizes.
- Measure worst-case output duration for 1,000 English characters and set timeout/output ceilings.

Exit: one deployed authenticated test endpoint can clone and generate without retaining request files, and measured Modal settings replace guesses in configuration.

### Phase 1: Monorepo and Quality Baseline

- Scaffold Flutter Android app and Python backend.
- Add formatting, static analysis, unit-test, migration, secret-scan, and OpenAPI-drift CI jobs.
- Establish environment configuration for local, staging, and production without committed secrets.
- Add typed error contracts and shared JSON fixtures.
- Establish the global Material 3 theme, semantic tokens, system/light/dark modes, motion tokens, and baseline light/dark golden tests before feature screens proliferate.

Exit: empty app/backend builds and all CI gates pass.

### Phase 2: Identity, User Bootstrap, and Usage

- Configure Firebase Google provider and Android signing fingerprints.
- Implement first-launch onboarding, mandatory Google sign-in, post-auth Pro preview with Skip, sign-out, token injection/refresh, and backend verification.
- Create Neon users, Plan Policies, and usage-period migrations.
- Implement `/v1/me` and `/v1/usage`, including policy-version and UTC period tests.

Exit: a Google-authenticated User completes onboarding and sees accurate server-owned Free limits; unverified requests cannot reach inference and the Pro preview makes no false billing claim.

### Phase 3: Local Persistence Shell

- Add Drift schema/migrations and identity-scoped filesystem service.
- Implement atomic write/delete and startup reconciliation.
- Build empty/loading/error/history states using fake repositories.
- Implement MP3 playback, rename, share, and delete against fixture audio.
- Implement Settings theme mode and Android document-tree export destination with revoked-permission recovery.

Exit: local history and preferences survive restart and handle missing files, revoked export access, low storage, and interrupted writes without crashing.

### Phase 4: Voice Cloning Vertical Slice

- Implement consent UI, microphone permission, constrained WAV recording, preview, and retake.
- Add backend active-slot and monthly Clone Allowance reservation, inference, manifest signing, cleanup, and `/v1/voices` reconciliation.
- Persist Voice Profiles locally and support rename/delete.
- Test interrupted upload/download, process death, active voice limit, monthly clone limit, deletion without quota refund, UTC renewal, manifest integrity, and backend-only orphan cleanup.

Exit: a User can reliably create, restart with, select, and delete up to two valid local Voice Profiles, while no more than two successful creations are allowed per UTC month.

### Phase 5: Generation Vertical Slice

- Add text composition, character counter, voice selection, and explicit operation states.
- Implement backend leases, idempotency, quota checks, state verification, inference, MP3 encoding, and Usage charging.
- Persist/play successful output and display ambiguous-delivery guidance.
- Refresh Usage after success and quota/concurrency failures.

Exit: end-to-end cloned speech is generated, charged once, stored locally, and playable after restart.

### Phase 6: Content and Account Lifecycle

- Implement pending deletion retries, bulk Clear Content, sign-out isolation, and account switching tests.
- Implement account deletion and Firebase recent-reauth flow.
- Complete Settings usage cards, Pro entry, download location, theme mode, replay onboarding, privacy, and version rows.
- Complete the globally themed subscription preview and Skip behavior; leave Google Play purchase actions disabled until billing is implemented end-to-end.
- Finalize tombstone/purchase retention with privacy/legal review.
- Add privacy disclosures for temporary processing, local-only files, uninstall loss, Usage charging, and deletion behavior.

Exit: clear, sign-out, account switch, reinstall, and account deletion have tested and accurately disclosed outcomes.

### Phase 7: Hardening and Release

- Load-test quota and concurrency races across multiple backend processes/containers.
- Verify no sensitive payload appears in app, FastAPI, Modal, database, or crash logs.
- Tune Modal minimum/maximum containers, timeouts, CPU, memory, and scale-to-zero from measurements.
- Capture Flutter DevTools frame traces and remove repeatable jank from onboarding, recording waveform/timer, long history scrolling, theme switching, and subscription transitions.
- Run accessibility, reduced-motion, text scaling, 320dp-width, offline, denied-permission, revoked-export-access, low-storage, process-death, and network interruption tests.
- Verify release signing, Firebase production configuration, privacy policy, and Play Data Safety declarations.

Exit: all acceptance scenarios pass on at least one low/mid-range physical Android device and one current reference device.

## 8. Test Strategy

Flutter unit tests:

- state transitions and failure mapping
- filename/title validation
- identity storage partitioning
- filesystem/Drift compensation and reconciliation
- pending deletion retries
- token refresh retry policy
- theme preference and onboarding policy persistence
- export destination permission loss and fallback
- server Plan Policy mapping without client-side authority

Flutter widget tests:

- onboarding, mandatory auth gate, sign-in failure, Pro preview, and Skip
- consent and recording bounds
- empty/loading/error/success states for every screen
- generated-duration, active-voice, monthly clone, character, and quota limits
- generation ambiguity warning
- Settings quota, download, subscription, and theme controls
- accessible labels, focus order, reduced motion, and large text
- light/dark golden states at small and representative phone widths

Backend unit tests:

- Firebase claim mapping
- Plan Policy validation, versioning, and UTC period boundaries
- successful clone charging and deletion without allowance refund
- final-request overage behavior
- manifest signing, tampering, owner mismatch, and key rotation
- media validation and duration calculation
- error redaction

Backend integration tests against PostgreSQL:

- simultaneous clone requests cannot exceed active or monthly policy limits
- failed clone creation does not consume allowance
- successful clone creation consumes allowance even if response delivery is interrupted
- deletion frees an active slot but does not refund allowance; a new UTC period restores allowance
- simultaneous Generation requests permit only one lease per User
- duplicate request IDs charge once
- expired leases recover after process failure
- failed inference does not charge
- completed inference charges full measured duration
- deleted/inactive profiles cannot generate
- User A cannot access User B metadata or Voice Profile
- text and media bytes never appear in persisted rows

End-to-end physical-device tests:

- first-launch onboarding, Google sign-in, Pro preview Skip, returning launch, and token expiry
- microphone denial and recovery
- clone, persist, restart, and generate
- two successful clones, deletion, blocked third clone, and next-period renewal fixture
- interrupted upload and download
- process death during local commit
- MP3 play/share/delete
- Voice Profile delete while Generations remain playable
- quota rejection and bounded final overage
- system/light/dark switching, process restart, and reduced-motion behavior
- choose/change/revoke download destination and export MP3
- Clear Content, sign-out/account switch, reinstall, and Delete Account

## 9. Verification Commands

Exact commands are finalized with project scaffolding. CI must include equivalents of:

```text
flutter format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
ruff check backend
ruff format --check backend
pytest backend/tests
alembic upgrade head
```

The Modal deployment receives a post-deploy smoke test using synthetic non-sensitive audio and text. Production smoke tests must clean up their active voice metadata.

## 10. Release Acceptance

- Mandatory Google sign-in protects every product API.
- Onboarding explains local storage and temporary processing, then presents mandatory Google sign-in and a skippable, truthful Pro preview.
- A Free User can hold at most two active, cryptographically bound Voice Profiles and successfully create at most two per UTC month.
- Deleting a Voice Profile frees active capacity but does not refund monthly Clone Allowance.
- Effective limits are returned from versioned server Plan Policy and can change without a Flutter release.
- Reference recordings and inference artifacts are absent after request cleanup.
- A valid Voice Profile produces a complete MP3 from at most 1,000 characters.
- One User cannot run two concurrent Generations across separate containers.
- Successful duration is charged exactly once to the correct UTC period.
- No text, voice bytes, recordings, or generated audio are retained by Neon or backend storage.
- Local writes and deletes recover cleanly after interruption.
- History audio can be played, renamed, shared, and deleted.
- Settings supports download destination, Pro preview, quota display, and system/light/dark modes.
- All screens consume the global theme and remain usable on supported phone widths and large text.
- Physical-device profile traces contain no known repeatable release-blocking animation or scrolling jank.
- Clear Content retains User/Usage/Clone Allowance/plan; Delete Account follows the documented compliance path.
- Privacy copy clearly states that uninstalling or clearing app data can permanently remove local content.

## 11. Explicitly Deferred

- Google Play Billing, real purchases, backend purchase verification, acknowledgement, RTDN, and paid entitlement activation; MVP includes only the themed Pro preview and Skip flow
- 2,000-character paid requests
- additional languages and models
- audio or Voice Profile import
- streaming generation/playback
- cloud backup, cloud file storage, and cross-device sync
- export/import of Voice Profiles
- Redis, queues, Kubernetes, dedicated GPU capacity, and multiple inference providers
- analytics beyond operational, quota, and minimal generation metadata

## 12. Risks to Close Before Feature Build

- Modal CPU cost and latency assumptions require Phase 0 measurements; do not adopt the PRD's guessed CPU/RAM/container values unchanged.
- Quantization may affect quality or library compatibility and remains conditional on the spike.
- MP3 bitrate and reference recording sample rate need listening tests on physical Android devices.
- The chosen warm off-white/coral/near-black palette must pass light/dark contrast and golden review before being frozen as tokens.
- Smoothness is a measured release criterion, not a guarantee from animation APIs; low/mid-range device profiles determine whether decorative motion is retained.
- Android document-tree access can be revoked externally; app-private files remain canonical and export must recover without data loss.
- Future Google Play billing requires backend verification, acknowledgement, and subscription lifecycle reconciliation before any entitlement is granted.
- Account-deletion tombstones and future purchase retention need privacy/legal validation and explicit expiry.
- A server-completed result can consume Usage even when the client never receives it; the MVP intentionally accepts this because it retains no audio for redelivery.
- Local-only storage means uninstall, clear-data, device loss, and unrecoverable filesystem corruption can permanently destroy content.
