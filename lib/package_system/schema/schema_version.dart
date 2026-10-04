/// Curriculum schema versioning.
///
/// Every content document carries `schemaVersion`. The engine reads versions in
/// [kMinReadableSchemaVersion]..[kCurrentSchemaVersion]; older documents are
/// upgraded in memory by `SchemaMigrator` before parsing. When the content
/// format changes in a way old data cannot satisfy:
///   1. bump [kCurrentSchemaVersion],
///   2. register a migration (N -> N+1) in `schema_migrator.dart`,
///   3. update `tool/validate_content.py` specs.
/// `tool/validate_content.py` reads these two constants, so CI fails if the
/// validator and the engine ever disagree.
const int kCurrentSchemaVersion = 1;
const int kMinReadableSchemaVersion = 1;
