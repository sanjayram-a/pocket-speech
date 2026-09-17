# Pocket Speech

Pocket Speech lets a person generate speech entirely on their Android device
with Pocket TTS — using built-in native voices or a personal Voice Profile
cloned from their own voice. There is no account and no backend.

## Language

**Voice Engine**:
The versioned sherpa-onnx Pocket TTS INT8 model files downloaded on first use,
verified against a pinned size and SHA-256, and shared by all voices. Never
bundled in the APK.

**Built-in Voice**:
A native `pocket-tts` voice ID (Alba, Javert, Bill Boerst, Caro Davy,
Fantine) whose source recording is downloaded silently from Kyutai's
`tts-voices` repository with per-file integrity pinning. Alba is the default
voice.

**Voice Profile**:
A person's own reference recording plus local metadata, created from an
in-app recording and stored privately on-device. The recording is retained
because Pocket TTS uses it as the direct cloning reference for every
Generation.

**Reference Recording**:
An in-app mono WAV of 5–12 seconds, captured after an explicit consent
attestation. Edge noise is trimmed on save; the spoken start is never faded
or cut beyond that trim.

**Generation**:
A text-to-speech result produced on-device by the Voice Engine using exactly
one selected voice. Saved as an app-private WAV and listed in History.
Generated input text is transient and never persisted.

**History**:
The local list of Generations with playback, export, and delete. Metadata is
a single JSON file reconciled against orphaned WAV files on load.

**Download Location**:
A user-selected Android document tree used only to export copies of
generated audio. Canonical audio always remains app-private.

## Relationships

- A **Generation** uses exactly one **Voice** — either one **Built-in Voice**
  or one **Voice Profile**.
- A **Voice Profile** is created from exactly one **Reference Recording** and
  keeps it for as long as the profile exists.
- The **Voice Engine** is required for every **Generation** but is not
  required to record or store a **Voice Profile**.
- A **Generation** appears in **History** only after its audio file is safely
  written.
- An **export copy** leaves the device only when the person picks a
  **Download Location** and explicitly exports.

## Resolved Decisions

- No account, sign-in, or server component exists in this product.
- Cloning and generation run on-device; nothing about the person's recordings,
  text, or results ever leaves the device except explicit exports.
- The Voice Engine downloads only after install, resumes interrupted
  transfers, and activates atomically; failures show their real cause.
- Built-in voices exclude non-commercially licensed sources (Expresso/EARS);
  CC BY 4.0 voices are attributed in Settings and `LICENSES.md`.
- Generated audio receives trailing-noise trim and tail fade-out only; the
  start of generated audio plays untouched.
- Deleting a Voice Profile keeps existing Generations playable.
- Uninstalling the app or clearing its data permanently removes all profiles,
  recordings, generated audio, and the downloaded Voice Engine.
