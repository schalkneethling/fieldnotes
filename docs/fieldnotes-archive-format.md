# Fieldnotes archive format

Fieldnotes archives are UTF-8 JSON documents saved through the system document picker. The format is independent of the SwiftData store so a store schema refactor does not silently redefine existing archives.

## Version 1

The root object contains:

- `format`: the fixed identifier `com.schalkneethling.fieldnotes.archive`.
- `formatVersion`: the integer `1`.
- `exportedAtUnixSeconds`: the export time as finite seconds since the Unix epoch.
- `fieldnotes`: every Fieldnote, ordered by creation time and then identifier for deterministic output.

Each Fieldnote contains:

- `id`: its UUID.
- `createdAtUnixSeconds`: its exact stored date as finite seconds since the Unix epoch.
- `text`: the complete text.
- `emoji`: the stored feeling string, or `null`.
- `photoData`: the complete photo bytes encoded using JSON `Data` base64, or `null`.

JSON object keys are sorted during export. Consumers must use the named keys rather than depend on key order.

## Restore semantics

Version 1 restore is additive and all-or-nothing:

- An identifier not present locally is inserted.
- An identifier with identical date, text, feeling, and photo bytes is already present and skipped.
- An identifier with any different value is a conflict. The complete restore is rejected before insertion.
- Equal content with different identifiers remains two distinct Fieldnotes.
- Restore never deletes or overwrites a local Fieldnote.

The archive is fully validated before mutation. Missing Fieldnotes are inserted through a dedicated SwiftData context with autosave disabled and one explicit save; a save failure rolls back every insertion.

## Limits and privacy

Version 1 accepts at most:

- 256 MiB for the encoded archive;
- 10,000 Fieldnotes;
- 1 MiB of UTF-8 text per Fieldnote;
- 32 MiB per decoded photo; and
- 180 MiB of decoded photo data in total.

Capture, export, and restore apply the same limits so a successful write cannot leave Fieldnotes with a version 1 store it cannot export. Capture checks a SwiftData aggregate count plus transactionally maintained photo-byte and encoded-size totals rather than loading existing Fieldnotes; V1-to-V2 migration backfills those totals once. Import opens the selected path without following symlinks, checks the resulting descriptor is a regular file within the limit, reads at most the limit plus one byte from that same descriptor, then verifies the byte count and file size again afterward.

Archives are not encrypted by Fieldnotes. They contain private Fieldnote content and should be stored somewhere the owner trusts. An archive is a manual point-in-time copy, not an automatic backup or synchronization service.
