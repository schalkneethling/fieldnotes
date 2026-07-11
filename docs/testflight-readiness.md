# TestFlight readiness plan

## Objective

Ship a stable internal TestFlight build that lets a small tester group validate capture reliability, local persistence, dictation, photo handling, and the usefulness of review cues on real devices.

## Current assessment

The core product loop is implemented: capture a short note, optionally attach a feeling and photo, persist it locally, and review notes by time range. The project has a shared scheme, bundle identifier, marketing version, build number, and automatic-signing configuration.

The first TestFlight upload is blocked by missing release assets, an unproven signed archive, lack of automated tests, and incomplete release operations. The deployment target is iOS 26.0, which must be confirmed against the intended tester devices.

## Release gates

The first internal build is ready when all of the following are true:

- The app has a production app icon and accent-color asset.
- The minimum iOS version is an explicit product decision.
- A Release archive succeeds with the intended Apple Developer team.
- Xcode Organizer validation succeeds without blocking errors.
- Core capture and review behavior passes on at least one physical iPhone.
- Camera, photo library, microphone, and speech permission flows are tested for both approval and denial.
- Notes persist across app termination and installation of a newer build.
- Users can remove an accidental or unwanted note.
- Stored photos are resized and normalized to control storage and memory use.
- Core date-range, reflection-cue, and persistence behavior has automated coverage.
- App Store Connect beta metadata, privacy answers, export compliance, support URL, privacy-policy URL, and tester instructions are complete.
- The build number is unique and the tester-facing changes are recorded.

## Trial scope

Start with 3–5 internal testers for one week. Ask testers to create notes using typing, dictation, camera capture, and photo-library selection; deny and later grant each permission; force-quit and relaunch the app; review each time range; and report crashes, lost content, confusing interactions, excessive storage, or misleading reflection cues.

External testing should follow only after the internal trial has no known data-loss or launch-blocking defects and the Beta App Review information is complete.

## Deliberate non-goals for the first trial

- Accounts or cross-device sync.
- Cloud backup managed by the app.
- AI-provider integration.
- Analytics or advertising.
- Broad localization.
- Public App Store release.

## Release procedure

1. Confirm the target version and increment the build number.
2. Run automated tests and a Release build.
3. Complete the physical-device smoke checklist.
4. Archive using the shared `Fieldnotes` scheme.
5. Validate and upload through Xcode Organizer.
6. Add the build to the internal tester group with focused “What to Test” notes.
7. Record feedback and regressions in GitHub Issues.
8. Tag the exact source revision used for the accepted trial build.

## Known environment note

A command-line Release compilation attempted during the readiness review was blocked because the sandbox could not run the SwiftData macro plugin. This did not establish a source-code failure. The signed archive and validation must be performed in an unrestricted Xcode environment before distribution.
