import SwiftData

enum FieldnotesSchemaV1: VersionedSchema {
    // Keep this model identity unchanged while adopting versioning. Before V2,
    // preserve the V1 model definition rather than editing it in place.
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [Fieldnote.self]
}

enum FieldnotesMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [FieldnotesSchemaV1.self]
    static let stages: [MigrationStage] = []
}

enum FieldnotesStoreFactory {
    static let schema = Schema(versionedSchema: FieldnotesSchemaV1.self)

    static var defaultConfiguration: ModelConfiguration {
        ModelConfiguration(schema: schema)
    }

    static func makeContainer(configuration: ModelConfiguration? = nil) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: FieldnotesMigrationPlan.self,
            configurations: [configuration ?? defaultConfiguration]
        )
    }
}
