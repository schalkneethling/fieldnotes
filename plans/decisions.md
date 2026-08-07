# Fieldnotes decision log

This is an append-oriented record of decisions that future contributors and Codex tasks should not have to reconstruct from conversation history.

Statuses:

- **Accepted:** governs current work.
- **Provisional:** current working assumption that still needs validation.
- **Open:** an explicit decision remains.
- **Superseded:** retained for history and linked to its replacement.

## D-001 — Persist plans in the repository and execution in GitHub

- **Date:** 2026-08-03
- **Status:** Accepted
- **Decision:** Keep active plans and decisions in the checked-in `plans/` directory. Use GitHub epics and issues as the authoritative tracker for executable work and completion state.
- **Reason:** Project knowledge must survive missing or inaccessible conversation history without creating conflicting status copies.

## D-002 — Begin with a one-person internal trial

- **Date:** 2026-08-03
- **Status:** Accepted
- **Decision:** The first TestFlight trial has one tester: the project owner, using the primary physical trial device.
- **Consequence:** The first trial can focus deeply on daily use, reliability, and distribution behavior. External testing and Beta App Review are deferred.

## D-003 — Use two one-time signature experiences

- **Date:** 2026-08-03
- **Status:** Accepted
- **Decision:** Invest in a distinctive first-launch reveal and a separate acknowledgment for the first successfully persisted Fieldnote.
- **Constraint:** Both must remain restrained, accessible, and one-time so ordinary capture stays fast and unobtrusive.

## D-004 — Offer optional permission preparation during onboarding

- **Date:** 2026-08-03
- **Status:** Accepted
- **Decision:** Onboarding may prepare camera and voice permissions so later capture is not unexpectedly interrupted. Every capability can be skipped. A native prompt is shown only after the user explicitly elects to enable that capability.
- **Consequence:** Skipped capabilities remain available contextually and denied capabilities provide a route to system Settings. Broad photo-library permission is not requested when a system picker can provide the selected media without it.

## D-005 — Treat reliability and performance as first-trial release gates

- **Date:** 2026-08-03
- **Status:** Accepted
- **Decision:** Go beyond a minimal smoke suite. Cover critical flows, real-store persistence, migrations, retrieval, failure recovery, UI behavior, regressions, and measurable device performance.
- **Consequence:** The primary physical trial device is the first performance baseline, including representative collections of 100, 1,000, and 5,000 Fieldnotes.

## D-006 — Keep iOS 26.0 as the self-trial floor

- **Date:** 2026-08-03
- **Status:** Accepted
- **Decision:** Do not lower the deployment target solely for the one-person trial because the current target supports the trial device.
- **Consequence:** Project and test targets remain on iOS 26.0 for the internal trial. Decide and validate the eventual public minimum separately before broader distribution.

## D-007 — Define the durability boundary for device loss and app deletion

- **Date:** 2026-08-03
- **Decided:** 2026-08-06
- **Status:** Accepted
- **Decision:** Manual export and restoration are release gates for the first internal trial. Export a versioned JSON archive containing every Fieldnote field and attached photo. Restore additively: missing identifiers are inserted, identical identifiers are treated as already present, and a differing Fieldnote with the same identifier rejects the entire restore. Restoration never overwrites or deletes local Fieldnotes.
- **Safety boundary:** Validate the complete archive before mutation, restore with one explicit save in a dedicated non-autosaving context, and roll back on failure. Reject non-regular, unsupported, malformed, conflicting, or oversized archives without changing the store. The first format is capped at 256 MiB and uses one opened file descriptor for bounded pre-read and post-read checks. New captures and restores enforce the same version 1 limits so a successful write cannot make the store unexportable.
- **Privacy and backup boundary:** Archives are portable but are not encrypted by Fieldnotes. The owner chooses a private destination and must export again to capture later changes. Fieldnotes does not yet provide automatic backup, cloud synchronization, accounts, background exports, or recovery without an accessible archive.
- **Reason:** A one-person trial still creates meaningful personal data. A deliberate portable copy makes app deletion and device replacement recoverable without expanding the trial into an account or sync system.
- **Tracking:** GitHub issues #21 and #24.

## D-008 — Require pull requests for changes to main

- **Date:** 2026-08-03
- **Status:** Accepted
- **Decision:** All work, including administrator changes, must reach `main` through a pull request from a `codex/` branch.
- **Enforcement:** GitHub branch protection requires a pull request, applies to administrators, requires zero approvals for solo maintenance, and disables force-pushes and branch deletion.
- **Reason:** Directly publishing the initial planning commit bypassed review and left no branch diff. The repository and `AGENTS.md` now make the intended workflow explicit.

## D-009 — Never replace a failed persistent store implicitly

- **Date:** 2026-08-05
- **Status:** Accepted
- **Decision:** Create the SwiftData container through an explicit versioned-schema factory and present loading, ready, or recovery states at launch. If the store cannot open, retain the original store and block capture rather than creating an empty or in-memory fallback.
- **Recovery behavior:** Permit retry against the same store and expose sanitized diagnostics containing only app/build versions, OS version, an allowlisted and bounded error-code chain, and a session support reference that is also written to local unified logs. Do not expose raw error messages, store paths, device identifiers, or Fieldnote content. If opening exceeds the timeout, show recovery information but do not start another opener until the original synchronous attempt returns.
- **Schema constraint:** V1 owns a structurally frozen `Fieldnote` model exposed to the app through a typealias. Future versions define a separate model rather than editing V1 in place. A checked-in store created by the pre-versioning API and model is the compatibility fixture.
- **Reason:** An unexplained crash is unusable, while a silent replacement store could make existing Fieldnotes appear lost and allow new captures into the wrong durability context.
