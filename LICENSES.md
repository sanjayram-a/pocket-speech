# Voice and model licenses

## Built-in voices

Native Pocket TTS voice IDs, sourced from the recordings that Kyutai used to
create the official voice embeddings (see `kyutai-labs/pocket-tts`,
`_ORIGINS_OF_PREDEFINED_VOICES`).

| Voice | Source recording | License |
|---|---|---|
| Alba | `alba-mackenna/casual.wav` | CC BY 4.0 - (c) Alba MacKenna |
| Fantine | `vctk/p244_023_enhanced.wav` | CC BY 4.0 - VCTK (University of Edinburgh) |
| Javert | `voice-donations/Butter.wav` | CC0 - Kyutai Unmute Voice Donation Project |
| Bill Boerst | `voice-zero/bill_boerst.wav` | CC0 - LibriVox via Voice-Zero |
| Caro Davy | `voice-zero/caro_davy.wav` | CC0 - LibriVox via Voice-Zero |

Excluded from this app because of non-commercial or unclear licensing:
`cosette` (Expresso, CC BY-NC), `jean` (EARS, CC BY-NC), and the
Common Voice / Azure-derived multilingual voices.

CC BY 4.0 requires attribution, which is provided in-app (Settings >
Guidance and privacy > Built-in voices) and in this file.

## Model

- Runtime: sherpa-onnx (Apache-2.0)
- Pocket TTS INT8 model bundle: license included in the upstream archive
  (`sherpa-onnx-pocket-tts-int8-2026-01-26`, kyutai/pocket-tts weights).
