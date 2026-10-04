import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n5_kanji_journey/core/storage.dart';
import 'package:n5_kanji_journey/lessons/lesson_screen.dart';
import 'package:n5_kanji_journey/package_system/journey_loader.dart';
import 'package:n5_kanji_journey/prefectures/unlock_evaluator.dart';
import 'package:n5_kanji_journey/progress/progress_service.dart';
import 'package:n5_kanji_journey/tests/test_session.dart';
import 'support/disk_pack_source.dart';
import 'support/harness.dart';

void main() {
  test('the two complete packages load with shared knowledge and no diagnostics', () async {
    final c = await JourneyLoader(DiskPackSource()).load();
    expect(c.diagnostics, isEmpty);
    expect(c.prefectures.take(3).map((p) => p.id), ['hokkaido', 'aomori', 'iwate']);
    expect(c.prefectures.take(3).every((p) => p.installed), isTrue);
    for (final id in ['aomori', 'iwate']) {
      final p = c.pack(id)!;
      expect(p.chapters, hasLength(3));
      expect(p.lessons, hasLength(4), reason: 'three location lessons and one reading');
      expect(p.lessons.values.every((l) => !l.isDraft), isTrue);
      expect(p.readingLesson!.cards, hasLength(12));
      expect(p.questions, hasLength(60));
      for (final q in p.questions) {
        expect(q.choices, hasLength(4));
        expect(q.choices.where((ch) => ch.id == q.answerId), hasLength(1));
        for (final ref in q.refs) {
          expect(c.knowledge.kanji(ref) ?? c.knowledge.radical(ref) ??
              c.knowledge.vocabulary(ref) ?? c.knowledge.grammar(ref) ??
              c.knowledge.sentence(ref), isNotNull, reason: '${q.id} -> $ref');
        }
      }
      for (var seed = 0; seed < 5; seed++) {
        final s = TestSession.start(p.manifest.tests.single, p.questions, seed: seed);
        expect(s.questions, hasLength(30));
        for (final cat in ['kanji', 'radical', 'numbers', 'vocabulary', 'grammar', 'reading']) {
          expect(s.questions.where((q) => q.category == cat), hasLength(5));
        }
        expect(s.passed(20), isFalse);
        expect(s.passed(21), isTrue);
      }
    }
    expect(c.pack('aomori')!.lessons.values.where((l) => l.id != 'aomori_reading')
        .fold<int>(0, (n, l) => n + l.cards.length), 36);
    expect(c.pack('iwate')!.lessons.values.where((l) => l.id != 'iwate_reading')
        .fold<int>(0, (n, l) => n + l.cards.length), 37);
    expect(c.knowledge.lessonsForKanji('kanji_青').map((a) => a.lessonQualifiedId),
        contains('aomori/aomori_l01'));
  });

  test('prefecture, chapter, reading and test gates follow the supplied route', () async {
    final c = await JourneyLoader(DiskPackSource()).load();
    final p = ProgressService(MemoryStorage());
    await p.load();
    final u = UnlockEvaluator(c, p);
    expect(u.isPrefectureUnlocked('aomori'), isFalse);
    await p.recordTestResult('hokkaido/hokkaido_final', TestResult(21, 30, true, DateTime(2026, 10, 4)));
    expect(u.isPrefectureUnlocked('aomori'), isTrue);
    expect(u.isChapterUnlocked('aomori', 'hirosaki'), isFalse);
    expect(u.isReadingUnlocked('aomori'), isFalse);
    for (final city in ['aomori', 'hirosaki', 'hachinohe']) {
      expect(u.isLessonUnlocked('aomori', city, '${city}_l01'), isTrue);
      await p.markLessonComplete('aomori/${city}_l01');
    }
    expect(u.isReadingUnlocked('aomori'), isTrue);
    expect(u.isTestUnlocked('aomori', 'aomori_final'), isFalse);
    await p.markLessonComplete('aomori/aomori_reading');
    expect(u.isTestUnlocked('aomori', 'aomori_final'), isTrue);
    expect(u.isPrefectureUnlocked('iwate'), isFalse);
    await p.recordTestResult('aomori/aomori_final', TestResult(21, 30, true, DateTime(2026, 10, 4)));
    expect(u.isPrefectureUnlocked('iwate'), isTrue);
    for (final city in ['morioka', 'hiraizumi', 'hanamaki']) {
      expect(u.isLessonUnlocked('iwate', city, '${city}_l01'), isTrue);
      await p.markLessonComplete('iwate/${city}_l01');
    }
    expect(u.isReadingUnlocked('iwate'), isTrue);
    await p.markLessonComplete('iwate/iwate_reading');
    expect(u.isTestUnlocked('iwate', 'iwate_final'), isTrue);
    expect(u.isPrefectureComplete('iwate'), isFalse);
    await p.recordTestResult('iwate/iwate_final', TestResult(21, 30, true, DateTime(2026, 10, 4)));
    expect(u.isPrefectureComplete('iwate'), isTrue);
    expect(c.pack('miyagi'), isNotNull);
    expect(u.isPrefectureUnlocked('miyagi'), isTrue);
  });

  testWidgets('each installed location opens through the existing lesson renderer', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    for (final pref in ['aomori', 'iwate']) {
      final p = services.catalog.pack(pref)!;
      for (final chapter in p.chapters) {
        final lesson = p.lessons[chapter.lessonRefs.single.id]!;
        await tester.pumpWidget(harness(services,
            KeyedSubtree(key: ValueKey(lesson.qualifiedId), child: LessonScreen(lesson: lesson))));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('card-arrival')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: lesson.qualifiedId);
      }
    }
  });
}
