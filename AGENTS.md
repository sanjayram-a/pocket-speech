# Pocket Speech Engineering Guide

## Product Scope

Pocket Speech is an Android-first Flutter app for cloning a user's voice and generating speech with Kyutai Pocket TTS. Voice profiles and generated audio remain on-device; Modal performs temporary inference, and Neon stores only identity, quota, and generation metadata.

## MVP Boundaries

- Target Android with Flutter and Dart null safety.
- Keep cloned voice profiles and generated audio in app-local storage.
- Do not permanently retain reference recordings, voice profiles, generated audio, or generated text on the backend.
- Require Google sign-in before product use, authenticate every inference request, and derive the user ID from the verified token.
- Enforce active-voice, monthly voice-creation, usage, request-size, and concurrency limits on the server.
- Resolve limits from server-owned plan policy so Free and future Pro quotas can change without a client release.
- Measure quota using successfully generated audio duration.
- Keep billing, cloud file storage, cross-device sync, queues, Redis, and additional inference providers out of the MVP.

## Architecture

- Keep the Flutter app in `app/`, the Modal/FastAPI service in `backend/`, and shared API fixtures in `contracts/`.
- Organize Flutter code by feature with explicit presentation, application, domain, and data boundaries where they provide value; avoid ceremonial layers.
- Scope local files and metadata to the authenticated Firebase identity so account switching cannot expose another user's content.
- Treat the local metadata store and filesystem as one consistency boundary. Handle partial writes and deletion failures explicitly.
- Keep HTTP contracts typed and map transport errors into domain failures before they reach widgets.
- Bind every local voice-state file to its owner, server voice ID, model version, and byte hash with a server-signed manifest; verify it before inference.
- Model asynchronous UI with explicit idle, loading, success, and failure states.
- Define all colors, typography, shapes, spacing, and component styles in one global Material 3 theme; feature widgets must not hard-code presentation colors.
- Support system-default, light, and dark theme modes.
- Use composition, const widgets, accessible semantics, and minimum 48dp touch targets.
- Profile animations on physical Android devices and fix jank before release; respect reduced-motion accessibility settings.
- Never log tokens, generated text, voice-state bytes, reference recordings, or generated audio.

## Quality Gates

- Format and statically analyze Dart code.
- Unit-test Plan Policy, quota, repository, and failure-mapping logic.
- Widget-test loading, error, empty, and success states.
- Integration-test onboarding, Google sign-in, cloning, monthly clone quota, generation, persistence, playback, export, settings, deletion, and quota rejection.
- Golden-test core screens in light and dark themes at representative phone sizes and large text scales.
- Verify critical flows on a physical Android device, including interrupted uploads/downloads, process death, low storage, and denied permissions.

## Working Agreements

- Keep changes small and MVP-focused.
- Add dependencies only for a concrete requirement.
- Never trust client-supplied identity, plan, quota, duration, or subscription state.
- Update product/domain documentation when terminology or architectural decisions change.
