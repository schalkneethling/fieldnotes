import SwiftData

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
