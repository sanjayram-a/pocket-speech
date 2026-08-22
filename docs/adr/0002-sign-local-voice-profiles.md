# Sign local voice profiles

The cloning service returns a signed manifest binding the authenticated user, server voice ID, Pocket TTS model version, and SHA-256 hash of the returned voice-state bytes. Generation verifies that manifest and the active Neon voice row before inference, enforcing ownership and voice-count limits without retaining voice data on the backend or trusting a client-supplied voice ID.
