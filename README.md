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

Camera, photo-library, microphone, and speech-recognition access are requested only when the corresponding feature is used. App Store Connect privacy answers and this statement must be reviewed whenever data handling changes.

## TestFlight readiness

The release plan and trial acceptance criteria are documented in [docs/testflight-readiness.md](docs/testflight-readiness.md). Work is also tracked as epics and subtasks in GitHub Issues.

