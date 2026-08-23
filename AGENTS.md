# Pocket Speech Engineering Guide

## Product Scope

Pocket Speech is an Android-first Flutter app for text-to-speech with zero-shot
voice cloning, running entirely on-device with the sherpa-onnx Pocket TTS INT8
model. Users can generate speech with built-in native Pocket TTS voices or with
a personal Voice Profile recorded from their own voice. There is no account,
no backend, and no telemetry; everything stays on the device.

## Repository Layout

The Flutter app lives at the repository root — there is no `app/` nesting and
no backend:

```
lib/           Dart source, organized by feature
  app/         Bootstrap, theme tokens, global controllers (Riverpod)
  core/        Model installer, audio helpers, shared primitives
  features/    generation, voices, history, model, settings, navigation,
               onboarding
test/          Unit and widget tests mirroring lib/
android/       Android host project
```

## MVP Boundaries

- Target Android only, with Dart null safety.
- Reference recordings, Voice Profiles, built-in voices, and generated audio
  live in app-private storage (`getApplicationSupportDirectory`).
- Generated input text is transient: never persisted to metadata or history.
- No authentication. Network is used only for the one-time downloads below.
- The voice engine (`sherpa-onnx-pocket-tts-int8-2026-01-26`) is downloaded on
  first use, never bundled: resume interrupted downloads via HTTP range
  requests, verify pinned size + SHA-256, extract through a resumable staging
  directory, and atomically activate only after every required file exists.
- Built-in voices (Alba, Javert, Bill Boerst, Caro Davy, Fantine) are the
  native `pocket-tts` voice IDs; they download silently from
  `kyutai/tts-voices` with per-file size + SHA-256 pinning. Marius was removed.
  Never bundle voices in the APK or add non-commercially licensed ones
  (Expresso/EARS are CC BY-NC — excluded). Attribution lives in Settings and
  `LICENSES.md`.
- Keep billing, cloud storage, sync, quotas, queues, analytics, and additional
  inference providers out of scope.

## Architecture

- State management is Riverpod 3 (`Notifier` / `AsyncNotifier`); repositories
  are plain classes injected at bootstrap in `main.dart` via provider
  overrides.
- sherpa-onnx generation runs in a dedicated long-lived isolate that owns the
  native engine; it communicates over typed maps on `SendPort`s. Recreate the
  isolate when sensitive content is deleted or the model changes.
- Isolate boundaries carry only sendable data (strings, numbers, records).
  Capture locals explicitly in `Isolate.run` closures — implicit `this`
  capture has caused `ArgumentError: object is unsendable`.
- Model installation is recoverable: partial `.part` archives auto-resume, a
  decompressed sidecar tar with a completion marker skips redoing bzip2 after
  process death, extraction retries three times, and real failure causes are
  shown in the UI plus persisted to `last_install_error.txt`.
- Audio post-processing (`audio_post_processor.dart`): generated output gets a
  conservative trailing-hiss trim and tail fade-out only — never trim or fade
  the start of generated audio or references' heads beyond edge-noise removal;
  the first phoneme must play untouched.
- History metadata lives in a single JSON file with atomic tmp-rename writes;
  orphaned WAVs are reconciled back into history on load, deduplicated by
  path.
- Exports use the Storage Access Framework (`Download location` setting);
  canonical copies always stay app-private.
- Map all failures into typed exceptions with user-facing messages before they
  reach widgets; show real diagnostic detail for install errors.
- Define all colors, typography, shapes, spacing in `app_theme.dart`; feature
  widgets consume semantic tokens (`context.spacing`, `context.shapes`) and
  never hard-code colors. Support system/light/dark modes.
- Use composition, const widgets, accessible semantics, 48dp touch targets.
- The bottom nav bar has curved top corners (`AppShapes.navBar`, radius 28).

## Quality Gates

Run from the repo root before handing off any change:

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

- Unit-test model download/verification/recovery, builtin-voice integrity,
  repositories, WAV parsing, and audio post-processing.
- Widget-test loading, error, empty, and success states.
- Verify install, cloning, generation, playback, export, and deletion flows on
  a physical Android device (interrupted downloads, process death, low
  storage, denied mic permission).

## Working Agreements

- Keep changes small and focused; add dependencies only for a concrete need.
- Never report a model or voice installed before its integrity checks pass.
- Never log generated text, reference recordings, or generated audio bytes.
- When terminology changes, update this file and `README.md` together.
