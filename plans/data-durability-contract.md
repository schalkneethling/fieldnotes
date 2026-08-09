# Fieldnotes data-durability contract

- **Status:** Active draft for the first internal trial
- **Last updated:** 2026-08-09
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
9. A manually exported archive contains every Fieldnote field and attached photo, and can restore missing Fieldnotes after app deletion or onto a replacement device without overwriting existing data.

## Explicit boundaries

Recovery after deleting the app, losing the device, or losing access to the device requires a recent manually exported archive that remains accessible. Fieldnotes cannot recover changes made after the last export and cannot recover anything if both the device and archive are unavailable.

Fieldnotes does not create automatic or cloud backups, synchronize devices, schedule exports, or encrypt archives. The JSON archive contains private text, feelings, timestamps, identifiers, and base64-encoded photo data. The owner is responsible for choosing a private storage destination. The [versioned archive format and limits](../docs/fieldnotes-archive-format.md) are documented independently of SwiftData.

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

### Archive restore failure

- Open the selected URL without following symlinks, verify that the descriptor refers to a regular file, and reject an archive over 256 MiB before reading it.
- Read at most 256 MiB plus one byte from that same descriptor, then repeat the byte limit and expected-size checks afterward.
- Validate the format, version, counts, finite timestamps, unique identifiers, text limits, and photo limits before changing SwiftData.
- Treat an identical identifier and identical content as already restored.
- Reject the entire archive if an identifier matches a different local Fieldnote.
- Enforce the same archive limits when capturing and restoring Fieldnotes, keeping every successful store state exportable.
- Insert all missing Fieldnotes in a dedicated non-autosaving context and call one explicit save. Roll back every insertion if that save fails.

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
| Manual export and restoration | Deterministic codec, bounded-read, exact round-trip, idempotency, conflict, and rollback tests | Export to Files, remove/reinstall, restore, relaunch, and compare text and media |
| Scale and responsiveness | Deterministic save-cost test at 1,000 and 5,000 records plus performance tests at representative collection sizes | Instruments run on the primary trial device |

## Current gaps

- Explicit throwing save and complete-Fieldnote integration tests are implemented in the first reliability slice; failure injection and UI coverage remain.
- The save operation now has a repository seam for deterministic cost testing; save-failure injection and UI coverage remain incomplete.
- The V1 schema and model shape remain structurally frozen and pinned by tests. V2 adds transactional archive-usage metadata, and the checked-in pre-versioning store proves migration preserves every Fieldnote field and external photo data while backfilling that metadata.
- Store initialization now has testable idle, opening, ready, timeout-recovery, and error-recovery paths. Injected failures prove that no fallback or overlapping container is created; controlled invalid-store and physical-device recovery checks remain.
- There is now a unit-test target, but no comprehensive critical-flow or UI suite yet.
- New camera and library photos share a pre-persistence normalization pipeline: source orientation is applied, the longest edge is capped at 2,048 pixels, output uses one fixed JPEG quality of 0.82, and stored data is capped at 8 MiB without silent quality fallback. Capture discloses that Fieldnotes keeps an optimized copy rather than the original. Physical-device verification with representative camera and library formats remains.
- Manual JSON export and additive restoration are implemented with a 256 MiB cap. Capture and restore update aggregate archive usage transactionally, so a new save does not walk existing external photo data. Physical-device recovery and representative-library performance remain to be verified. Automatic backup and synchronization remain out of scope.
- Confirmed deletion now removes the Fieldnote and archive-usage metadata in one explicit non-autosaving transaction. Disk-reopen and injected-save-failure tests cover persistence and rollback; UI automation and physical-device relaunch verification remain.
- Review fetches the full collection and filters time ranges in memory.
- Image decoding occurs from view rendering and has no explicit memory budget.

These gaps are addressed incrementally through epic #14 and its linked subtasks. A first successful-save fix is the initial implementation slice; it does not close this contract by itself.
