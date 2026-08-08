import SwiftData

enum FieldnotesMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        FieldnotesSchemaV1.self,
        FieldnotesSchemaV2.self
    ]
    static let stages: [MigrationStage] = [
        .custom(
            fromVersion: FieldnotesSchemaV1.self,
            toVersion: FieldnotesSchemaV2.self,
            willMigrate: nil,
            didMigrate: { context in
                try FieldnotesArchiveUsageRepository.reconcile(in: context)
            }
        )
    ]
}

enum FieldnotesStoreFactory {
    static let schema = Schema(versionedSchema: FieldnotesSchemaV2.self)

    static var defaultConfiguration: ModelConfiguration {
        ModelConfiguration(schema: schema)
    }

    static func makeContainer(configuration: ModelConfiguration? = nil) throws -> ModelContainer {
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FieldnotesMigrationPlan.self,
            configurations: [configuration ?? defaultConfiguration]
        )
        try FieldnotesArchiveUsageRepository.ensurePresent(in: ModelContext(container))
        return container
    }
}
