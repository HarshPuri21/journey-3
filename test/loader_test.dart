import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:n5_kanji_journey/package_system/journey_loader.dart';
import 'package:n5_kanji_journey/package_system/pack_source.dart';
import 'package:n5_kanji_journey/package_system/schema/schema_migrator.dart';

import 'support/disk_pack_source.dart';

void main() {
  test('shipped content loads cleanly through the real loader', () async {
    final catalog = await JourneyLoader(DiskPackSource()).load();
    expect(catalog.diagnostics, isEmpty);
    expect(catalog.packs.map((p) => p.id).toSet(), {'hokkaido', 'aomori', 'iwate', 'miyagi', 'akita', 'yamagata', 'fukushima', 'ibaraki', 'tochigi', 'gunma'});

    final h = catalog.pack('hokkaido')!;
    expect(h.chapters.map((c) => c.id),
        ['sapporo', 'hakodate', 'chitose', 'otaru', 'asahikawa', 'biei', 'furano', 'kushiro', 'noboribetsu']);
    final lesson = h.lessons['sapporo_l01']!;
    expect(lesson.isDraft, isFalse);
    expect(lesson.cards, hasLength(15), reason: 'the 14 supplied cards + the city-name radicals card');
    expect(lesson.cards.map((c) => c.id), contains('inside_sapporo'));
    expect(h.lessons.values.every((lesson) => !lesson.isDraft), isTrue);
    expect(lesson.cards.last.scroll, isTrue, reason: '"Things to Remember" is the long, scrollable card');
    expect(lesson.coreKanjiIds, ['kanji_北', 'kanji_海', 'kanji_道']);

    // Route order comes from data; all ten supplied prefectures are installed.
    final route = catalog.prefectures;
    expect(route.first.id, 'hokkaido');
    expect(route.first.installed, isTrue);
    expect(route.take(10).every((p) => p.installed), isTrue);
    expect(route.skip(10).every((p) => !p.installed), isTrue);
  });

  test('reading module, test bank and package metadata load', () async {
    final catalog = await JourneyLoader(DiskPackSource()).load();
    final h = catalog.pack('hokkaido')!;
    expect(h.readingLesson, isNotNull);
    expect(h.readingLesson!.cards, hasLength(22));
    expect(h.readingLesson!.cards.last.scroll, isTrue);
    expect(h.questions, hasLength(60));
    final test = h.manifest.tests.single;
    expect(test.questionCount, 30);
    expect(test.quotas.values.fold<int>(0, (a, b) => a + b), 30);
    expect(h.manifest.completionCriteria, hasLength(23));
  });

  test('every test question links to knowledge ids that exist', () async {
    final catalog = await JourneyLoader(DiskPackSource()).load();
    final repo = catalog.knowledge;
    for (final q in catalog.pack('hokkaido')!.questions) {
      expect(q.refs, isNotEmpty, reason: q.id);
      for (final r in q.refs) {
        final found = repo.kanji(r) ?? repo.radical(r) ?? repo.vocabulary(r) ?? repo.grammar(r) ?? repo.sentence(r);
        expect(found, isNotNull, reason: '${q.id} -> $r');
      }
    }
  });

  test('city-name components are linked: 氵 / 木 / 川 reach every kanji that uses them', () async {
    final repo = (await JourneyLoader(DiskPackSource()).load()).knowledge;
    expect(repo.kanjiUsingRadical('radical_ki').map((k) => k.char), containsAll(['札', '樽']));
    expect(repo.kanjiUsingRadical('radical_kawa').map((k) => k.char), containsAll(['川', '釧']));
    expect(repo.kanji('kanji_道')!.relatedKanji, contains('kanji_路'));
  });

  test('a Journey with zero packs is still valid', () async {
    final index = readAllContent()[kIndexPath]!;
    final catalog = await JourneyLoader(MemoryPackSource({kIndexPath: index})).load();
    expect(catalog.packs, isEmpty);
    expect(catalog.prefectures, isNotEmpty);
    expect(catalog.prefectures.every((p) => !p.installed), isTrue);
  });

  test('one unreadable knowledge file drops only that file', () async {
    final files = readAllContent();
    const path = 'content/packs/hokkaido/knowledge/kanji.json';
    final doc = jsonDecode(files[path]!) as Map<String, dynamic>;
    doc['schemaVersion'] = 99;
    files[path] = jsonEncode(doc);

    final catalog = await JourneyLoader(MemoryPackSource(files)).load();
    expect(catalog.pack('hokkaido'), isNotNull);
    expect(catalog.diagnostics.any((d) => d.message.contains('kanji.json')), isTrue);
    expect(catalog.knowledge.kanji('kanji_北'), isNull);
    expect(catalog.knowledge.vocabulary('vocab_北海道'), isNotNull);
  });

  test('a pack with an unavailable dependency is skipped, others still load', () async {
    final files = readAllContent();
    files['content/packs/iwate/manifest.json'] = jsonEncode({
      'schemaVersion': 1,
      'kind': 'packManifest',
      'packId': 'iwate',
      'type': 'prefecture',
      'contentVersion': 1,
      'engineSchemaMin': 1,
      'title': '岩手',
      'dependencies': ['atlantis'],
    });
    final catalog = await JourneyLoader(MemoryPackSource(files)).load();
    expect(catalog.pack('hokkaido'), isNotNull);
    expect(catalog.pack('iwate'), isNull);
    expect(catalog.diagnostics.any((d) => d.scope == 'iwate'), isTrue);
  });

  test('schema evolution: an older document is migrated before parsing', () async {
    // Pretend the engine moved to schema 2 and v1 -> v2 needed no data change.
    final migrator = SchemaMigrator(current: 2, minReadable: 1, migrations: {1: (d) => d});
    final catalog = await JourneyLoader(DiskPackSource(), migrator: migrator).load();
    expect(catalog.diagnostics, isEmpty);
    expect(catalog.pack('hokkaido')!.lessons, isNotEmpty);
  });
}
