# Fieldnotes

Fieldnotes is a local-first iOS app for quickly capturing a short observation, an optional feeling, and one photo. Notes are stored on the device with SwiftData and can be reviewed across daily, weekly, and monthly views.

## Current capabilities

- Capture notes of up to 240 characters.
- Add a photo from the camera or photo library.
- Dictate notes using on-device speech recognition.
- Add an optional emotion signal.
- Review recent notes and locally generated reflection cues.
- Keep all content on-device; the app currently makes no network requests.

## Requirements

- Xcode 26 or newer.
- An iOS 26 simulator or device with the current project settings.
- An Apple Developer team for device builds and TestFlight distribution.

## Development

Open `Fieldnotes.xcodeproj` in Xcode and run the shared `Fieldnotes` scheme.

The convenience script in `scripts/build-and-launch.sh` targets a developer-specific simulator and is not the canonical build path. For general development, select an available simulator in Xcode.

## Privacy

Fieldnotes currently has no account system, analytics, advertising SDKs, backend, or other network integration. Notes, photos, emotion signals, and speech-derived text remain on the device. Speech recognition is configured to require on-device recognition.

Camera, microphone, and speech-recognition access are requested only after the user explicitly chooses to prepare that capability during onboarding or invokes it later in context. Each onboarding permission can be skipped. Photo selection should use the system picker without requesting broader library access when possible. App Store Connect privacy answers and this statement must be reviewed whenever data handling changes.

## TestFlight readiness

The durable planning hub is in [plans/README.md](plans/README.md), with the active [TestFlight self-trial plan](plans/testflight-self-trial.md) and [decision log](plans/decisions.md). Release gates are documented in [docs/testflight-readiness.md](docs/testflight-readiness.md), while individual work and completion state are tracked in GitHub Issues.
