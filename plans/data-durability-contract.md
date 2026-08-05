# Fieldnotes data-durability contract

- **Status:** Active draft for the first internal trial
- **Last updated:** 2026-08-05
- **Tracking:** [GitHub issue #21](https://github.com/schalkneethling/fieldnotes/issues/21)

## Purpose

This contract defines when Fieldnotes may tell someone that a Fieldnote is saved, which loss scenarios the first internal trial protects against, and how those claims are verified.

## Trial guarantees

For the first internal trial, Fieldnotes must guarantee that:

1. A successful capture acknowledgment occurs only after SwiftData explicitly saves the Fieldnote.
2. A save failure keeps the editor and its draft visible, reports that nothing was saved, and permits a retry.
3. A successfully saved Fieldnote remains available after dismissing the editor, force-quitting, relaunching, rebooting, and installing a compatible newer TestFlight build.
4. Text, feeling, timestamp, identifier, and attached media are committed as one logical Fieldnote. The interface must not report partial success.
5. Retrieval returns every persisted Fieldnote once, in deterministic newest-first order.
6. Deletion requires explicit confirmation and is considered complete only after its persistence succeeds.
7. A store-open or migration failure never silently replaces or deletes the existing store.
8. Schema changes ship with a versioned schema, an explicit migration path, and a test fixture created by the previous released schema.

## Explicit boundaries

The first internal build does not yet promise recovery after deleting the app, losing the device, or losing access to the device. Local SwiftData persistence alone cannot satisfy those scenarios.

Before broader testing, decide whether export and restoration are release gates or documented limitations. Until that decision is implemented, Fieldnotes must not describe local-only storage as a backup.

## Failure behavior

### Save failure

- Keep the full draft in the editor.
- Do not show the first-Fieldnote or ordinary save-success treatment.
- Roll back the failed insertion.
- Show a concise message that the Fieldnote was not saved and that the draft remains available.
- Permit retry or cancellation without silently discarding text or media.

### Store-open or migration failure

- Do not create a replacement persistent store at the same location.
- Do not offer capture into an ephemeral store that looks durable.
- Present a recovery state with diagnostic and support information.
- Preserve the original store for a future recovery or export path.

### Media-processing failure

- Keep the text draft usable.
- Explain that the selected image could not be prepared.
- Never attach the original unbounded media as a fallback.
- Require the user to remove or replace failed media before saving.

## Verification matrix

| Claim | Automated verification | Physical-device verification |
| --- | --- | --- |
| Explicit save and retrieval | Real temporary SwiftData store integration test | Save, force-quit, relaunch, retrieve |
| Failed save retains draft | Persistence seam failure test and UI test | Induced storage failure where practical |
| Deterministic ordering | Equal and varied timestamp fixtures | Review a seeded realistic collection |
| Compatible build upgrade | Previous-schema migration fixture | Install a newer TestFlight build over existing data |
| Atomic text and media | Integration tests for success and processing failure | Save and retrieve normalized camera and picker media |
| Confirmed durable deletion | Integration and UI tests | Delete, force-quit, and verify absence after relaunch |
| Store-open failure safety | Container factory failure test | Validate recovery UI with a controlled invalid store copy |
| Scale and responsiveness | Performance tests at representative collection sizes | Instruments run on the primary trial device |

## Current gaps

- Explicit throwing save and complete-Fieldnote integration tests are implemented in the first reliability slice; failure injection and UI coverage remain.
- There is no save-operation seam for deterministic failure testing; startup failure injection is now covered separately.
- The V1 schema is explicitly versioned, and a disk-backed compatibility test proves a store created by the prior unversioned configuration reopens without losing a complete Fieldnote. No V2 migration fixture exists yet because no schema change has shipped.
- Store initialization now has a testable loading, ready, and recovery path. Injected failures prove that no fallback container is created; controlled invalid-store and physical-device recovery checks remain.
- There is now a unit-test target, but no comprehensive critical-flow or UI suite yet.
- Library media is stored in its original representation and camera media is compressed without resizing.
- Deletion, export, backup, and restoration are not implemented.
- Review fetches the full collection and filters time ranges in memory.
- Image decoding occurs from view rendering and has no explicit memory budget.

These gaps are addressed incrementally through epic #14 and its linked subtasks. A first successful-save fix is the initial implementation slice; it does not close this contract by itself.
