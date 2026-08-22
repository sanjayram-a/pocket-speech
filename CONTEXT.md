# Pocket Speech

Pocket Speech lets a person create an on-device voice profile and use it to generate locally retained speech through temporary cloud inference.

## Language

**User**:
A Google-authenticated person whose identity, plan, and quota are tracked by the backend.
_Avoid_: Account, customer

**Voice Profile**:
A locally stored English Pocket TTS voice-state file and signed ownership manifest created from a temporary Reference Recording.
_Avoid_: Cloned voice, voice file

**Generation**:
A server-completed text-to-speech result retained on-device as MP3 whose duration counts toward Usage, even if delivery is interrupted.
_Avoid_: Job, request

**Reference Recording**:
An in-app lossless WAV recording of the User speaking a consent phrase, supplied temporarily to create a Voice Profile and discarded after processing.
_Avoid_: Voice sample

**Usage**:
The total duration of successful Generations charged to a User in the current UTC calendar month.
_Avoid_: Request count, character count

**Clone Allowance**:
The number of successful Voice Profile creations available to a User in the current UTC calendar month.
_Avoid_: Active voice limit, replacement credits

**Plan Policy**:
The server-owned set of limits and entitlements applied to a User's plan.
_Avoid_: Client configuration, subscription status

**Clear Content**:
Deletion of local Voice Profiles and generated audio plus deactivation of corresponding server voice metadata, while retaining the User, Usage, Clone Allowance, plan, and purchase history.
_Avoid_: Delete account, reset account

**Delete Account**:
Deletion of the User's identity and personal data through a distinct compliance flow, subject to narrowly retained fraud-prevention or purchase records where legally permitted.
_Avoid_: Clear content, sign out

## Relationships

- A **User** owns zero or more **Voice Profiles**, subject to the server-enforced plan limit.
- A **Voice Profile** is created from exactly one **Reference Recording**.
- A **Generation** uses exactly one **Voice Profile**.
- A successful **Generation** increases the **User's** **Usage** by its audio duration.
- A successfully created **Voice Profile** consumes one unit of the **User's** **Clone Allowance**.
- A **Plan Policy** defines active Voice Profile, Clone Allowance, Usage, character, request-size, and concurrency limits.

## Example Dialogue

> **Developer:** "Do we retain the Reference Recording after creating the Voice Profile?"
> **Domain expert:** "No. The backend processes it temporarily, returns the Voice Profile, and retains neither file."

## Flagged Ambiguities

- The PRD's anonymous bootstrap is superseded: Google sign-in through Firebase Authentication is mandatory before cloning or generation.
- "Clone locally" means the resulting Voice Profile is stored locally, not that voice cloning inference runs on the device.
- "Monthly" for free Usage means a UTC calendar month beginning at 00:00 UTC on its first day; future paid billing periods are separate.
- A Generation is charged when inference completes on the server; client delivery is not part of the success boundary.
- Free Users may have at most two active Voice Profiles and create at most two Voice Profiles per UTC calendar month.
- Deleting a Voice Profile frees its active slot but does not restore Clone Allowance; a replacement requires remaining monthly allowance or the next UTC renewal.
- MVP Voice Profiles and Generations support English only.
- MVP cloning accepts only a new in-app Reference Recording after explicit consent attestation; importing existing audio is excluded.
- **Clear Content** retains the **User's** plan, **Usage**, and **Clone Allowance**; **Delete Account** is a separate action.
- A Reference Recording is 10-30 seconds and at most 10 MB; Free Generation text is at most 1,000 Unicode characters, with 2,000 planned for paid plans.
- A Generation may take Usage beyond the monthly limit when it starts below the limit; its full duration is charged and subsequent requests are rejected.
- A Voice Profile's signed manifest binds its owner, server ID, model version, and byte hash; Generations reject altered, unowned, or inactive profiles.
- Generated input text is transient and is not retained in either local metadata or backend metadata.
- Only an in-app Reference Recording may be uploaded temporarily to Modal for Voice Profile creation; imported recordings remain excluded and no uploaded media is retained.
- Effective limits come from server-owned Plan Policy and are returned to the app for display; the client never grants entitlements.
