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
- **Status:** Open
- **Question:** Must the first trial support export and restoration, or is an explicit limitation acceptable until a later build?
- **Reason:** Local SwiftData persistence can protect ordinary saves and upgrades but cannot by itself recover data after device loss or app deletion.
- **Tracking:** GitHub issue #21.

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
- **Recovery behavior:** Permit retry against the same store and expose sanitized diagnostics containing only app/build versions, OS version, error domain/code, and a support reference. Do not expose raw error messages, store paths, device identifiers, or Fieldnote content.
- **Schema constraint:** V1 references the existing top-level `Fieldnote` model to preserve its shipped identity during versioning adoption. Do not edit that model in place for V2; first preserve the V1 definition and prove the transition with a previous-version fixture.
- **Reason:** An unexplained crash is unusable, while a silent replacement store could make existing Fieldnotes appear lost and allow new captures into the wrong durability context.
