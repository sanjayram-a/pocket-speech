# Pocket Speech Design Direction

Status: initial direction derived from the provided visual references. Tokens remain candidates until contrast, golden, and physical-device review.

## Design Intent

Pocket Speech should feel like a focused personal audio instrument: private, calm, tactile, and quick. The interface should emphasize the current voice, recording waveform, remaining allowance, and generated audio instead of dashboards or dense configuration.

Use the first reference for the overall visual language and palette. Use the second reference only for subscription information hierarchy. Do not copy either product's name, logo, exact composition, copy, illustrations, or decorative assets.

## Global Palette

Candidate light semantic colors inspired by the first reference:

| Token | Candidate | Purpose |
|---|---|---|
| Background | `#F4F4F1` | Warm neutral page background |
| Surface | `#FFFFFF` | Primary cards and sheets |
| Surface muted | `#ECECE8` | Secondary controls and disabled areas |
| Primary | `#F5663F` | Recording, progress, selection, and primary emphasis |
| Primary container | `#FFE9DF` | Soft selected and informational surfaces |
| On primary | `#FFFFFF` | Text/icons on primary |
| Ink | `#191917` | Main text and strongest controls |
| Muted ink | `#686862` | Supporting text and metadata |
| Outline | `#DDDCD6` | Dividers and quiet borders |
| Error | Material semantic red | Destructive/error state, contrast validated |

Candidate dark colors should preserve the same hierarchy rather than invert the light palette:

| Token | Candidate | Purpose |
|---|---|---|
| Background | `#10100F` | Dark page background |
| Surface | `#1B1B19` | Primary cards and sheets |
| Surface muted | `#252521` | Secondary controls |
| Primary | `#FF825E` | Warm accent adjusted for dark contrast |
| Primary container | `#522417` | Selected and informational surfaces |
| On primary | `#271008` | Text/icons on bright primary |
| Ink | `#F7F6F1` | Main text |
| Muted ink | `#B8B7B0` | Supporting text |
| Outline | `#3C3B36` | Dividers and quiet borders |

Run WCAG contrast checks before freezing these values. Components consume `ColorScheme` and theme extensions, never raw color constants.

## Visual Grammar

- Rounded rectangular cards with approximately 18-24dp corner radius and restrained tonal elevation.
- Pill-shaped primary actions and compact circular icon actions.
- Near-black high-emphasis controls balanced by one warm coral-orange accent.
- Generous vertical rhythm and whitespace; avoid filling every surface with cards.
- Waveform is the primary brand motif and may appear in recording, empty, loading, and playback states without becoming decorative noise.
- Use tabular figures for timers, duration, and Usage values.
- Prefer a bundled, legible variable sans-serif with a slightly rounded tone; validate licensing, APK size, and large-text readability before selection.
- Use a spacing scale of 4, 8, 12, 16, 24, and 32dp and central shape/type/motion tokens.

## Screen Direction

### Onboarding

- Use two or three short, full-height pages rather than a long feature carousel.
- Explain local storage and temporary cloud processing with a simple device-to-cloud-to-device visual.
- End with a prominent `Continue with Google` action and links to privacy/terms.
- Google authentication is mandatory; do not label it as skippable.
- After authentication, show the Pro preview as a separate screen with a clearly visible Skip action.

### Generate

- Make text composition the dominant surface, followed by the selected Voice Profile and one clear Generate action.
- Show the 1,000-character Free limit and remaining generated-duration Usage before submission.
- Keep the resulting player in context without crowding the composer.

### Voice Recording

- Take hierarchy inspiration from the reference's centered recording card: status, waveform, large timer, and clear pause/stop controls.
- Show the 10-second minimum and 30-second maximum without relying on color alone.
- Display active Voice Profile capacity and monthly Clone Allowance before conversion.
- Avoid live transcription because it is outside product scope and would expose unnecessary text processing.

### Voices and History

- Use compact cards with waveform/avatar mark, user-defined title, date, duration, and an overflow menu.
- Keep primary playback/select action reachable with one thumb.
- Use lazy lists and stable item heights where possible to protect scroll performance.

### Settings

- Place the Pro card and complete Usage summary first.
- Group download location, appearance, onboarding replay, privacy, account, and version settings into clear sections.
- Show generated-duration, successful-clone, and active-voice limits separately so deletion behavior is understandable.
- Use segmented or radio selection for `System default`, `Light`, and `Dark`; do not use an ambiguous binary dark-mode switch.

### Subscription Preview

- Borrow the second reference's plan name, benefit checklist, strong CTA region, and simple comparison hierarchy.
- Do not borrow its neon yellow/green color treatment or black-only visual identity.
- Apply the global Pocket Speech palette in both light and dark modes.
- MVP displays `Coming soon` instead of a fake price or enabled purchase action and always exposes Skip.
- When billing launches, render localized product names, billing periods, offers, and prices from Google Play data.

## Motion

- Use a small global duration set, initially approximately 120ms for feedback, 180ms for control changes, and 240ms for route/content transitions.
- Animate waveform amplitude, recording status, progress, selection, and content transitions only when motion communicates state.
- Avoid perpetual decorative motion on list and settings screens.
- Respect reduced-motion settings and provide static equivalents.
- Prefer transform/opacity animations over layout-heavy animation, but remove fully transparent animated layers when inactive.
- Keep animation rebuild scope local; waveform painters must not rebuild the full recording screen each frame.

## Responsive and Accessibility Rules

- Design first for one-handed portrait use, then validate landscape without making it a primary layout.
- Support 320dp width, common 360-430dp phones, display cutouts, gesture/navigation bars, and keyboard insets.
- Support at least 200 percent text scale without clipped titles, quotas, or actions.
- Use 48dp minimum touch targets, semantic labels, logical focus order, and non-color status indicators.
- Never encode plan, quota, recording, or destructive state through color alone.

## Review Artifacts

- Golden baselines for onboarding, Generate, recording, Voices, History, Settings, and subscription preview in light/dark themes.
- Golden variants at representative small phone width and large text.
- DevTools frame traces for recording waveform, long-list scrolling, theme switching, and route transitions.
- Physical-device review on low/mid-range 60Hz Android and a representative 120Hz Android device.
