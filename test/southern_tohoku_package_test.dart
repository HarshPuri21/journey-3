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
  test('Package 3 loads in route order with complete lessons, readings and resolved review links', () async {
    final c = await JourneyLoader(DiskPackSource()).load();
    expect(c.diagnostics, isEmpty);
    expect(c.prefectures.take(5).map((p) => p.id), ['hokkaido', 'aomori', 'iwate', 'miyagi', 'akita']);
    expect(c.prefectures.take(5).every((p) => p.installed), isTrue);
    for (final id in ['miyagi', 'akita']) {
      final p = c.pack(id)!;
      final count = id == 'miyagi' ? 4 : 3;
      expect(p.chapters, hasLength(count));
      expect(p.lessons, hasLength(count + 1));
      expect(p.lessons.values.every((l) => !l.isDraft), isTrue);
      expect(p.readingLesson!.cards, hasLength(12));
      expect(p.lessons.values.where((l) => l.id != '${id}_reading')
          .fold<int>(0, (n, l) => n + l.cards.length), count * 12);
      expect(p.questions, hasLength(60));
      for (final q in p.questions) {
        expect(q.choices, hasLength(4));
        expect(q.choices.where((choice) => choice.id == q.answerId), hasLength(1));
        expect(q.refs, isNotEmpty);
        for (final ref in q.refs) {
          expect(c.knowledge.kanji(ref) ?? c.knowledge.radical(ref) ??
              c.knowledge.vocabulary(ref) ?? c.knowledge.grammar(ref) ??
              c.knowledge.sentence(ref), isNotNull, reason: '${q.id} -> $ref');
        }
      }
      for (var seed = 0; seed < 10; seed++) {
        final s = TestSession.start(p.manifest.tests.single, p.questions, seed: seed);
        expect(s.questions, hasLength(30));
        for (final category in ['kanji', 'radical', 'numbers', 'vocabulary', 'grammar', 'reading']) {
          expect(s.questions.where((q) => q.category == category), hasLength(5));
        }
        expect(s.passed(20), isFalse);
        expect(s.passed(21), isTrue);
      }
    }
    expect(c.knowledge.lessonsForKanji('kanji_駅').map((a) => a.lessonQualifiedId), contains('miyagi/sendai_l01'));
    expect(c.knowledge.lessonsForKanji('kanji_読').map((a) => a.lessonQualifiedId), contains('akita/kakunodate_l01'));
  });

  test('Miyagi and Akita gates require lessons, reading and a passing test in sequence', () async {
    final c = await JourneyLoader(DiskPackSource()).load();
    final p = ProgressService(MemoryStorage());
    await p.load();
    final u = UnlockEvaluator(c, p);
    expect(u.isPrefectureUnlocked('miyagi'), isFalse);
    expect(u.isPrefectureUnlocked('akita'), isFalse);
    for (final id in ['hokkaido', 'aomori', 'iwate']) {
      await p.recordTestResult('$id/${id}_final', TestResult(21, 30, true, DateTime(2026, 10, 4)));
    }
    for (final id in ['miyagi', 'akita']) {
      final pack = c.pack(id)!;
      expect(u.isPrefectureUnlocked(id), isTrue);
      expect(u.isReadingUnlocked(id), isFalse);
      expect(u.isTestUnlocked(id, '${id}_final'), isFalse);
      for (var i = 0; i < pack.chapters.length; i++) {
        final chapter = pack.chapters[i];
        expect(u.isChapterUnlocked(id, chapter.id), isTrue);
        if (i + 1 < pack.chapters.length) {
          expect(u.isChapterUnlocked(id, pack.chapters[i + 1].id), isFalse);
        }
        final lessonId = chapter.lessonRefs.single.id;
        expect(u.isLessonUnlocked(id, chapter.id, lessonId), isTrue);
        await p.markLessonComplete('$id/$lessonId');
      }
      expect(u.isReadingUnlocked(id), isTrue);
      expect(u.isTestUnlocked(id, '${id}_final'), isFalse);
      await p.markLessonComplete('$id/${id}_reading');
      expect(u.isTestUnlocked(id, '${id}_final'), isTrue);
      expect(u.isPrefectureComplete(id), isFalse);
      await p.recordTestResult('$id/${id}_final', TestResult(20, 30, false, DateTime(2026, 10, 4)));
      expect(u.isPrefectureComplete(id), isFalse);
      if (id == 'miyagi') expect(u.isPrefectureUnlocked('akita'), isFalse);
      await p.recordTestResult('$id/${id}_final', TestResult(21, 30, true, DateTime(2026, 10, 4)));
      expect(u.isPrefectureComplete(id), isTrue);
    }
    if (c.pack('yamagata') != null) {
      expect(u.isPrefectureUnlocked('yamagata'), isTrue);
    }
  });

  testWidgets('all seven locations and both readings open in the existing renderer', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    for (final id in ['miyagi', 'akita']) {
      final pack = services.catalog.pack(id)!;
      for (final lesson in pack.lessons.values) {
        await tester.pumpWidget(harness(services,
            KeyedSubtree(key: ValueKey(lesson.qualifiedId), child: LessonScreen(lesson: lesson))));
        await tester.pumpAndSettle();
        final cardId = lesson.id == '${id}_reading' ? '${id}_r01' : 'arrival';
        expect(find.byKey(ValueKey('card-$cardId')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: lesson.qualifiedId);
      }
    }
  });
}
