# Pocket Speech Engineering Guide

## Product Scope

Pocket Speech is an Android-first Flutter app for cloning a user's voice and generating speech locally with the sherpa-onnx Pocket TTS INT8 model. Reference recordings, Voice Profiles, generated text, and generated audio remain on-device. The MVP does not require an account or inference backend.

## MVP Boundaries

- Target Android with Flutter and Dart null safety.
- Keep reference recordings, Voice Profiles, and generated audio in app-private storage.
- Do not retain generated input text after generation.
- Do not require authentication or network access after the optional model download.
- Download a pinned model artifact on first use; verify its expected size and SHA-256 before atomic activation.
- Keep billing, backend inference, cloud file storage, cross-device sync, quotas, queues, Redis, and additional inference providers out of the MVP.

## Architecture

- The Flutter app lives at the repository root; there is no backend in this MVP.
- Organize Flutter code by feature with explicit presentation, application, domain, and data boundaries where they provide value; avoid ceremonial layers.
- Treat the local metadata store and filesystem as one consistency boundary. Handle partial writes and deletion failures explicitly.
- Keep model installation and local inference behind narrow interfaces and map failures before they reach widgets.
- Run sherpa-onnx generation in a dedicated isolate that owns the native engine for its full lifetime.
- Model asynchronous UI with explicit idle, loading, success, and failure states.
- Define all colors, typography, shapes, spacing, and component styles in one global Material 3 theme; feature widgets must not hard-code presentation colors.
- Support system-default, light, and dark theme modes.
- Use composition, const widgets, accessible semantics, and minimum 48dp touch targets.
- Profile animations on physical Android devices and fix jank before release; respect reduced-motion accessibility settings.
- Never log tokens, generated text, voice-state bytes, reference recordings, or generated audio.

## Quality Gates

- Format and statically analyze Dart code.
- Unit-test model download, integrity verification, installation recovery, repositories, and failure mapping.
- Widget-test loading, error, empty, and success states.
- Integration-test onboarding, model installation, cloning, generation, persistence, playback, export, settings, and deletion.
- Golden-test core screens in light and dark themes at representative phone sizes and large text scales.
- Verify critical flows on a physical Android device, including interrupted uploads/downloads, process death, low storage, and denied permissions.

## Working Agreements

- Keep changes small and MVP-focused.
- Add dependencies only for a concrete requirement.
- Never mark a model installed before archive integrity and all required files have been verified.
- Update product/domain documentation when terminology or architectural decisions change.
