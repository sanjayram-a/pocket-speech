# Pocket Speech Flutter app

Android-first Flutter client for Pocket Speech. Authentication is mandatory;
Voice Profiles and generated audio will remain in identity-scoped app storage.

## Firebase configuration

Firebase configuration is supplied with compile-time Dart defines. No Firebase
keys or generated configuration files are committed. Provide all required
values to enable Google sign-in:

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID` (Android app ID for `com.dotwellabs.pocketspeech`)
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `GOOGLE_SERVER_CLIENT_ID` (OAuth web client ID used to obtain an ID token)
- `POCKET_SPEECH_API_BASE_URL` (HTTPS FastAPI origin, without a `/v1` suffix)

Optional values are `FIREBASE_STORAGE_BUCKET` and `FIREBASE_AUTH_DOMAIN`.
Configure the Firebase Android app, enable the Google authentication provider,
and register development/release SHA fingerprints in Firebase. Values passed as
Dart defines are compiled into the application; use the Firebase client values
only and never pass service-account or backend secrets.

When configuration is absent or invalid, the app remains runnable but mandatory
authentication cannot be bypassed. Attempting sign-in displays a configuration
error.

Run with individual defines:

```powershell
flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=... --dart-define=GOOGLE_SERVER_CLIENT_ID=... --dart-define=POCKET_SPEECH_API_BASE_URL=https://api.example.com
```

Or keep non-secret client configuration outside the repository and use:

```powershell
flutter run --dart-define-from-file=path/to/firebase.json
```

For an Android emulator talking to a local backend, use
`POCKET_SPEECH_API_BASE_URL=http://10.0.2.2:8000`. Plain HTTP is accepted only
for `localhost` and the Android emulator loopback alias; deployed builds require
HTTPS. Quota values are read from `/v1/usage` and are never treated as
client-owned entitlement state.

## Verification

```powershell
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```
