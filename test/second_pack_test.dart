import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n5_kanji_journey/core/storage.dart';
import 'package:n5_kanji_journey/knowledge/knowledge_repository.dart';
import 'package:n5_kanji_journey/lessons/lesson_screen.dart';
import 'package:n5_kanji_journey/package_system/journey_loader.dart';
import 'package:n5_kanji_journey/package_system/pack_source.dart';
import 'package:n5_kanji_journey/prefectures/unlock_evaluator.dart';
import 'package:n5_kanji_journey/progress/progress_service.dart';

import 'support/disk_pack_source.dart';
import 'support/harness.dart';

/// First-milestone criterion #18: a second prefecture package can be added
/// WITHOUT modifying the engine. This pack is pure data, installed by nothing
/// more than adding files to the source.
Map<String, String> filesWithAomori() {
  final files = readAllContent();
  // Keep this synthetic fixture isolated from newly installed real packs.
  files.removeWhere((path, _) => path.startsWith('content/packs/') &&
      !path.startsWith('content/packs/hokkaido/'));
  const base = 'content/packs/aomori';
  files['$base/manifest.json'] = jsonEncode({
    'schemaVersion': 1,
    'kind': 'packManifest',
    'packId': 'aomori',
    'type': 'prefecture',
    'contentVersion': 1,
    'engineSchemaMin': 1,
    'title': '青森',
    'titleEn': 'Aomori',
    'dependencies': ['hokkaido'],
    'unlock': [
      {'type': 'prefectureComplete', 'ref': 'hokkaido'}
    ],
    'chapters': [
      {'id': 'aomori_city', 'file': 'chapters/aomori_city.json', 'map': {'x': 0.5, 'y': 0.5}}
    ],
    'knowledge': {'kanji': 'knowledge/kanji.json'},
  });
  files['$base/chapters/aomori_city.json'] = jsonEncode({
    'schemaVersion': 1,
    'kind': 'chapter',
    'id': 'aomori_city',
    'name': '青森市',
    'lessons': [
      {'id': 'aomori_l01', 'file': 'lessons/aomori_l01.json'}
    ],
  });
  files['$base/lessons/aomori_l01.json'] = jsonEncode({
    'schemaVersion': 1,
    'kind': 'lesson',
    'id': 'aomori_l01',
    'number': 1,
    'title': 'Aomori',
    'coreKanji': ['kanji_青'],
    'cards': [
      {
        'id': 'aomori_welcome',
        'title': 'Aomori',
        'blocks': [
          {'type': 'display', 'jp': '青森', 'gloss': 'Aomori'},
          {'type': 'kanjiRef', 'id': 'kanji_青'},
          {'type': 'kanjiRef', 'id': 'kanji_北'}, // reused from Hokkaido
        ],
      }
    ],
  });
  files['$base/knowledge/kanji.json'] = jsonEncode({
    'schemaVersion': 1, 'kind': 'kanjiSet', 'items': <Object>[],
  });
  return files;
}

void main() {
  test('Aomori installs next to Hokkaido with no engine change', () async {
    final catalog = await JourneyLoader(MemoryPackSource(filesWithAomori())).load();
    expect(catalog.diagnostics, isEmpty);
    expect(catalog.packs.map((p) => p.id).toSet(), {'hokkaido', 'aomori'});
    expect(catalog.prefecture('aomori')!.installed, isTrue);
    expect(catalog.knowledge.kanji('kanji_青'), isNotNull);
    // Cross-pack reuse: the Aomori lesson references Hokkaido's 北.
    final apps = catalog.knowledge.lessonsForKanji('kanji_北').map((a) => a.lessonQualifiedId);
    expect(apps, containsAll(['hokkaido/sapporo_l01', 'aomori/aomori_l01']));
  });

  test('Aomori unlocks purely from its data rule', () async {
    final catalog = await JourneyLoader(MemoryPackSource(filesWithAomori())).load();
    final progress = ProgressService(MemoryStorage());
    await progress.load();
    final unlocks = UnlockEvaluator(catalog, progress);

    expect(unlocks.isPrefectureUnlocked('hokkaido'), isTrue);
    expect(unlocks.isPrefectureUnlocked('aomori'), isFalse);

    await progress.markLessonComplete('hokkaido/sapporo_l01');
    expect(unlocks.isPrefectureComplete('hokkaido'), isFalse, reason: 'Hokkaido completes when its test is passed');
    expect(unlocks.isPrefectureUnlocked('aomori'), isFalse);

    await progress.recordTestResult('hokkaido/hokkaido_final', TestResult(25, 30, true, DateTime(2026, 10, 1)));
    expect(unlocks.isPrefectureComplete('hokkaido'), isTrue);
    expect(unlocks.isPrefectureUnlocked('aomori'), isTrue);
    expect(unlocks.isLessonUnlocked('aomori', 'aomori_city', 'aomori_l01'), isTrue);
  });

  testWidgets('the same lesson screen renders the Aomori lesson', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices(source: MemoryPackSource(filesWithAomori()))))!;
    final lesson = services.catalog.lesson('aomori', 'aomori_l01')!;
    await tester.pumpWidget(harness(services, LessonScreen(lesson: lesson)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('card-aomori_welcome')), findsOneWidget);
    expect(find.text('青森'), findsOneWidget);
    expect(find.textContaining('blue'), findsOneWidget);
  });

  test('knowledge ids are shared infrastructure, not copied per lesson', () async {
    final catalog = await JourneyLoader(MemoryPackSource(filesWithAomori())).load();
    final roles = catalog.knowledge.lessonsForKanji('kanji_北').map((a) => a.role).toSet();
    expect(roles, containsAll([LessonRole.core, LessonRole.referenced]));
  });
}
