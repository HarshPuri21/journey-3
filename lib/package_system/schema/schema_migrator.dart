import '../../core/json_reader.dart';
import 'schema_version.dart';

/// Upgrades a raw content document from an older `schemaVersion` to the
/// current one *before* any typed parsing happens.
///
/// A migration is keyed by the version it upgrades FROM and must return a
/// document that is valid for (from + 1). Migrations run in sequence, so a
/// version-1 document is upgraded 1->2->3... until it is current.
typedef SchemaMigration = Map<String, dynamic> Function(Map<String, dynamic> doc);

class SchemaTooNewException extends ContentFormatException {
  SchemaTooNewException(String where, int found, int supported)
      : super('$where: schemaVersion $found is newer than this app reads '
            '($supported) - update the app');
}

class SchemaMigrator {
  SchemaMigrator({
    Map<int, SchemaMigration>? migrations,
    this.current = kCurrentSchemaVersion,
    this.minReadable = kMinReadableSchemaVersion,
  }) : _migrations = migrations ?? const <int, SchemaMigration>{};

  final int current;
  final int minReadable;
  final Map<int, SchemaMigration> _migrations;

  Map<String, dynamic> migrate(Map<String, dynamic> doc, {String where = 'document'}) {
    final v = doc['schemaVersion'];
    if (v is! int) {
      throw ContentFormatException('$where: missing integer "schemaVersion"');
    }
    if (v > current) throw SchemaTooNewException(where, v, current);
    if (v < minReadable) {
      throw ContentFormatException(
          '$where: schemaVersion $v is no longer supported (minimum $minReadable)');
    }
    var out = doc;
    var version = v;
    while (version < current) {
      final step = _migrations[version];
      if (step == null) {
        throw ContentFormatException(
            '$where: no migration registered from schemaVersion $version to ${version + 1}');
      }
      out = Map<String, dynamic>.from(step(Map<String, dynamic>.from(out)));
      version++;
      out['schemaVersion'] = version;
    }
    return out;
  }
}
