# SwiftData compatibility fixtures

`PreVersioningStore` is a disk-backed store generated before the V1 model was moved into `FieldnotesSchemaV1`. The generator used the prior `ModelContainer(for: Fieldnote.self, configurations:)` API and the unchanged top-level model definition from commit `5e0a53b`, which is byte-for-byte identical to the model on pre-PR commit `a33c900`.

The fixture contains one deterministic Fieldnote and its externally stored photo payload. Tests copy the complete fixture into a temporary directory before opening it through the current versioned store factory. Do not regenerate this fixture from the current model: its purpose is to remain independent historical input that exposes schema drift.
