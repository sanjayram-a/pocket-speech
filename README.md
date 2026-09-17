# Pocket Speech Flutter app

Android-first, account-free Flutter client for local Pocket TTS voice cloning
and speech generation. Reference recordings, text, and generated audio remain
on the device. No account, no backend, no telemetry.

## Offline voice engine

The app downloads the official [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
Pocket TTS INT8 archive on first use. It verifies the pinned archive size and
SHA-256 digest before extracting the required model files into the application
support directory. Interrupted downloads are resumed, incomplete installations
are staged separately, and an installation is activated only after every
required file is present.

Model: `sherpa-onnx-pocket-tts-int8-2026-01-26`

- Archive:
  [sherpa-onnx-pocket-tts-int8-2026-01-26.tar.bz2](https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-pocket-tts-int8-2026-01-26.tar.bz2)
  (~94 MB, SHA-256 verified before extraction)
- Upstream weights: [kyutai/pocket-tts](https://huggingface.co/kyutai/pocket-tts)
  (CC BY 4.0)
- Optional high-fidelity FP32 decoder from the same release:
  [csukuangfj2/sherpa-onnx-pocket-tts-2026-01-26](https://huggingface.co/csukuangfj2/sherpa-onnx-pocket-tts-2026-01-26)
  (~41 MB one-time download)

Runtime: [`sherpa_onnx`](https://pub.dev/packages/sherpa_onnx) 1.13.6
([source](https://github.com/k2-fsa/sherpa-onnx)) using the Android CPU
provider.

Voice Profiles are recorded as mono 24 kHz PCM WAV files and retained in
app-private storage. A selected Voice Profile is passed to Pocket TTS as the
zero-shot reference. Generated WAV files are persisted in local History and can
be played or deleted in the app.

Built-in voices (Alba, Javert, Bill Boerst, Caro Davy, Fantine) are the native
`pocket-tts` voice IDs. Their source recordings download silently from
[kyutai/tts-voices](https://huggingface.co/kyutai/tts-voices) with per-file
size + SHA-256 pinning. See [LICENSES.md](LICENSES.md) for voice and model
attribution.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.44+
  (Dart ^3.12.2, per `pubspec.yaml`)
- Android SDK + platform tools (`flutter doctor --android-licenses` accepted)
- An Android device (USB debugging enabled) or emulator — the app targets
  Android only
- Network access on first run (one-time ~94 MB voice-engine download)

## Running the app

From the repo root:

```powershell
flutter pub get
flutter doctor            # confirm Android toolchain + connected device
flutter run -d android    # or: flutter run (picks the connected device)
```

What to expect on first launch:

1. The app downloads the voice engine (~94 MB) with resumable progress.
2. Built-in voices download silently in the background when the voice picker
   is visible.
3. Record a Voice Profile (5–12 s in-app recording) or pick a built-in voice,
   enter text, and generate — all inference stays on-device.

Release install on a device:

```powershell
flutter build apk --release
flutter install
```

A debug APK (faster build, for local testing):

```powershell
flutter build apk --debug
```

## Verification

```powershell
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Privacy and storage

- Reference recordings, Voice Profiles, built-in voices, and generated audio
  live in app-private storage (`getApplicationSupportDirectory`).
- Generated input text is transient: never persisted to metadata or history.
- History metadata is a single JSON file with atomic tmp-rename writes.
- Exports use the Storage Access Framework (`Download location` setting);
  canonical copies always stay app-private.
- Uninstalling the app or clearing its data permanently removes all profiles,
  recordings, generated audio, and the downloaded voice engine.
