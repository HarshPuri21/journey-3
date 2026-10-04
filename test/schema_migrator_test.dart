import 'package:flutter_test/flutter_test.dart';
import 'package:n5_kanji_journey/core/json_reader.dart';
import 'package:n5_kanji_journey/package_system/schema/schema_migrator.dart';

void main() {
  final migrator = SchemaMigrator(
    current: 3,
    minReadable: 1,
    migrations: {
      1: (d) => {...d, 'title': d['name']}..remove('name'), // v1 -> v2: rename
      2: (d) => {...d, 'tags': <String>[]}, // v2 -> v3: new field
    },
  );

  test('upgrades step by step to the current version', () {
    final out = migrator.migrate({'schemaVersion': 1, 'name': 'Sapporo'});
    expect(out['schemaVersion'], 3);
    expect(out['title'], 'Sapporo');
    expect(out.containsKey('name'), isFalse);
    expect(out['tags'], isEmpty);
  });

  test('current documents pass through untouched', () {
    final doc = {'schemaVersion': 3, 'title': 'x'};
    expect(migrator.migrate(doc), doc);
  });

  test('documents newer than the app are rejected clearly', () {
    expect(() => migrator.migrate({'schemaVersion': 4}), throwsA(isA<SchemaTooNewException>()));
  });

  test('documents below the readable floor, or without a version, are rejected', () {
    final strict = SchemaMigrator(current: 3, minReadable: 2, migrations: {2: (d) => d});
    expect(() => strict.migrate({'schemaVersion': 1}), throwsA(isA<ContentFormatException>()));
    expect(() => strict.migrate({}), throwsA(isA<ContentFormatException>()));
  });

  test('a missing migration step is an explicit error, not silent corruption', () {
    final gap = SchemaMigrator(current: 3, minReadable: 1, migrations: {2: (d) => d});
    expect(() => gap.migrate({'schemaVersion': 1}), throwsA(isA<ContentFormatException>()));
  });
}
