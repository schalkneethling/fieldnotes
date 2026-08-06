# TestFlight readiness plan

## Objective

Ship a stable internal TestFlight build that lets the project owner validate capture reliability, local persistence, dictation, photo handling, performance, and the usefulness of review cues through daily use on the primary physical trial device.

## Current assessment

The core product loop is implemented: capture a short note, optionally attach a feeling and photo, persist it locally, and review notes by time range. The project has a shared scheme, bundle identifier, marketing version, build number, and automatic-signing configuration.

The first TestFlight upload is blocked by missing release assets, an unproven signed archive, incomplete critical-flow coverage, and incomplete release operations. The self-trial deployment target is confirmed as iOS 26.0; the eventual public minimum remains a separate decision.

## Release gates

The first internal build is ready when all of the following are true:

- The app has a production app icon and accent-color asset.
- The minimum iOS version is an explicit product decision for the intended distribution scope.
- A Release archive succeeds with the intended Apple Developer team.
- Xcode Organizer validation succeeds without blocking errors.
- Core capture and review behavior passes on at least one physical iPhone.
- Camera, photo library, microphone, and speech permission flows are tested for both approval and denial.
- Notes persist across app termination and installation of a newer build.
- Users can remove an accidental or unwanted note.
- Stored photos are resized and normalized to control storage and memory use.
- Critical capture, retrieval, deletion, relaunch, migration, and recovery behavior has comprehensive automated coverage.
- Explicit launch, capture, save, retrieval, scrolling, image-processing, dictation, and memory budgets pass on the primary physical trial device with representative data volumes.
- The first-launch and first-successful-Fieldnote experiences work across permission, accessibility, interruption, and relaunch states.
- The durability guarantee and its boundaries around app deletion, device loss, export, backup, and restoration are documented.
- App Store Connect beta metadata, privacy answers, export compliance, support URL, privacy-policy URL, and tester instructions are complete.
- The build number is unique and the tester-facing changes are recorded.

## Trial scope

Start with a one-person internal trial for one week on the primary physical trial device. Use the app for ordinary daily capture with typing, dictation, camera capture, and photo selection; exercise skipped, denied, and later granted permissions; force-quit and relaunch; install a newer TestFlight build; review each time range; and report crashes, lost content, ambiguous saves, slow interactions, confusing motion or permissions, excessive storage, or misleading reflection cues.

External testing should follow only after the internal trial has no known data-loss or launch-blocking defects and the Beta App Review information is complete.

The active execution order, design intent, recovered project history, and decision record live in [the checked-in planning hub](../plans/README.md). GitHub Issues remain authoritative for work-item status.

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
