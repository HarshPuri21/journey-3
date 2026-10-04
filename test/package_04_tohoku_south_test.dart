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
  test('Package 4 loads all seven lessons, readings and shared review references', () async {
    final c = await JourneyLoader(DiskPackSource()).load();
    expect(c.diagnostics, isEmpty);
    expect(c.prefectures.take(7).map((p) => p.id),
        ['hokkaido', 'aomori', 'iwate', 'miyagi', 'akita', 'yamagata', 'fukushima']);
    expect(c.prefectures.take(7).every((p) => p.installed), isTrue);
    for (final id in ['yamagata', 'fukushima']) {
      final p = c.pack(id)!;
      final count = id == 'yamagata' ? 3 : 4;
      expect(p.chapters, hasLength(count));
      expect(p.lessons, hasLength(count + 1));
      expect(p.lessons.values.every((l) => !l.isDraft), isTrue);
      expect(p.readingLesson!.cards, hasLength(12));
      expect(p.lessons.values.where((l) => l.id != '${id}_reading')
          .fold<int>(0, (n, l) => n + l.cards.length), count * 12);
      expect(p.questions, hasLength(60));
      for (final q in p.questions) {
        expect(q.choices, hasLength(4));
        expect(q.choices.where((ch) => ch.id == q.answerId), hasLength(1));
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
        for (final cat in ['kanji', 'radical', 'numbers', 'vocabulary', 'grammar', 'reading']) {
          expect(s.questions.where((q) => q.category == cat), hasLength(5));
        }
        expect(s.passed(20), isFalse);
        expect(s.passed(21), isTrue);
      }
    }
    final iwaki = c.pack('fukushima')!.chapters.singleWhere((ch) => ch.id == 'iwaki');
    expect(iwaki.name, 'いわき');
    expect(iwaki.reading, 'いわき');
    expect(c.knowledge.lessonsForKanji('kanji_話').map((a) => a.lessonQualifiedId), contains('fukushima/iwaki_l01'));
    expect(c.knowledge.lessonsForKanji('kanji_生').map((a) => a.lessonQualifiedId), contains('fukushima/koriyama_l01'));
    expect(c.knowledge.vocabulary('vocab_家')!.reading, 'いえ');
    expect(c.knowledge.vocabulary('vocab_家_home')!.reading, 'うち');
  });

  test('Akita pass, location completion, reading and passing tests control Package 4 gates', () async {
    final c = await JourneyLoader(DiskPackSource()).load();
    final p = ProgressService(MemoryStorage());
    await p.load();
    final u = UnlockEvaluator(c, p);
    expect(u.isPrefectureUnlocked('yamagata'), isFalse);
    expect(u.isPrefectureUnlocked('fukushima'), isFalse);
    for (final id in ['hokkaido', 'aomori', 'iwate', 'miyagi', 'akita']) {
      await p.recordTestResult('$id/${id}_final', TestResult(21, 30, true, DateTime(2026, 10, 4)));
    }
    for (final id in ['yamagata', 'fukushima']) {
      final pack = c.pack(id)!;
      expect(u.isPrefectureUnlocked(id), isTrue);
      expect(u.isReadingUnlocked(id), isFalse);
      expect(u.isTestUnlocked(id, '${id}_final'), isFalse);
      for (var i = 0; i < pack.chapters.length; i++) {
        final ch = pack.chapters[i];
        expect(u.isChapterUnlocked(id, ch.id), isTrue);
        if (i + 1 < pack.chapters.length) expect(u.isChapterUnlocked(id, pack.chapters[i + 1].id), isFalse);
        final lessonId = ch.lessonRefs.single.id;
        expect(u.isLessonUnlocked(id, ch.id, lessonId), isTrue);
        await p.markLessonComplete('$id/$lessonId');
      }
      expect(u.isReadingUnlocked(id), isTrue);
      expect(u.isTestUnlocked(id, '${id}_final'), isFalse);
      await p.markLessonComplete('$id/${id}_reading');
      expect(u.isTestUnlocked(id, '${id}_final'), isTrue);
      await p.recordTestResult('$id/${id}_final', TestResult(20, 30, false, DateTime(2026, 10, 4)));
      expect(u.isPrefectureComplete(id), isFalse);
      if (id == 'yamagata') expect(u.isPrefectureUnlocked('fukushima'), isFalse);
      await p.recordTestResult('$id/${id}_final', TestResult(21, 30, true, DateTime(2026, 10, 4)));
      expect(u.isPrefectureComplete(id), isTrue);
    }
    if (c.pack('ibaraki') != null) expect(u.isPrefectureUnlocked('ibaraki'), isTrue);
  });

  testWidgets('all seven locations and both readings open through the existing lesson renderer', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    for (final id in ['yamagata', 'fukushima']) {
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
