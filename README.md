# Pocket Speech Flutter app

Android-first, account-free Flutter client for local Pocket TTS voice cloning
and speech generation. Reference recordings, text, and generated audio remain
on the device.

## Offline voice engine

The app downloads the official sherpa-onnx Pocket TTS INT8 archive on first
use. It verifies the pinned archive size and SHA-256 digest before extracting
the required model files into the application support directory. Interrupted
downloads are resumed, incomplete installations are staged separately, and an
installation is activated only after every required file is present.

Model: `sherpa-onnx-pocket-tts-int8-2026-01-26`

Runtime: `sherpa_onnx` 1.13.6 using the Android CPU provider.

Voice Profiles are recorded as mono 24 kHz PCM WAV files and retained in
app-private storage. A selected Voice Profile is passed to Pocket TTS as the
zero-shot reference. Generated WAV files are persisted in local History and can
be played or deleted in the app.

## Verification

```powershell
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```
