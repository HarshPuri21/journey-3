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
  test('Package 5 extends the route and loads all thirteen complete locations', () async {
    final c = await JourneyLoader(DiskPackSource()).load();
    expect(c.diagnostics, isEmpty);
    expect(c.prefectures.take(10).map((p) => p.id), ['hokkaido', 'aomori', 'iwate',
      'miyagi', 'akita', 'yamagata', 'fukushima', 'ibaraki', 'tochigi', 'gunma']);
    expect(c.prefectures.take(10).every((p) => p.installed), isTrue);
    for (final id in ['ibaraki', 'tochigi', 'gunma']) {
      final p = c.pack(id)!;
      final count = id == 'ibaraki' ? 5 : 4;
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
        if (q.category == 'reading') {
          expect(q.prompt, contains('Passage ${id.toUpperCase()}-R'));
          expect(q.refs.where((ref) => ref.startsWith('sent_')), isNotEmpty);
        }
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
    final i = c.pack('ibaraki')!;
    expect(i.chapters.singleWhere((ch) => ch.id == 'tsukuba').name, 'つくば');
    expect(i.chapters.singleWhere((ch) => ch.id == 'kashima').name, '鹿嶋');
    expect(c.pack('gunma')!.chapters.singleWhere((ch) => ch.id == 'minakami').name, 'みなかみ');
    expect(c.knowledge.vocabulary('vocab_鹿島神宮')!.reading, 'かしまじんぐう');
    expect(c.knowledge.vocabulary('vocab_水上駅')!.reading, 'みなかみえき');
    expect(c.knowledge.lessonsForKanji('kanji_兄').map((a) => a.lessonQualifiedId), contains('tochigi/utsunomiya_l01'));
    final also = c.pack('tochigi')!.questions.singleWhere((q) => q.id == 'q_p05_tochigi_052');
    expect(also.prompt, contains('Passage TOCHIGI-R01:'));
    expect(also.prompt, contains('Passage TOCHIGI-R02:'));
  });

  test('Fukushima pass, location completion, reading and passing tests control the three new prefectures', () async {
    final c = await JourneyLoader(DiskPackSource()).load();
    final p = ProgressService(MemoryStorage());
    await p.load();
    final u = UnlockEvaluator(c, p);
    for (final id in ['ibaraki', 'tochigi', 'gunma']) expect(u.isPrefectureUnlocked(id), isFalse);
    for (final id in ['hokkaido', 'aomori', 'iwate', 'miyagi', 'akita', 'yamagata', 'fukushima']) {
      await p.recordTestResult('$id/${id}_final', TestResult(21, 30, true, DateTime(2026, 10, 4)));
    }
    for (final id in ['ibaraki', 'tochigi', 'gunma']) {
      final pack = c.pack(id)!;
      expect(u.isPrefectureUnlocked(id), isTrue);
      expect(u.isReadingUnlocked(id), isFalse);
      expect(u.isTestUnlocked(id, '${id}_final'), isFalse);
      for (var n = 0; n < pack.chapters.length; n++) {
        final ch = pack.chapters[n];
        expect(u.isChapterUnlocked(id, ch.id), isTrue);
        if (n + 1 < pack.chapters.length) expect(u.isChapterUnlocked(id, pack.chapters[n + 1].id), isFalse);
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
      if (id == 'ibaraki') expect(u.isPrefectureUnlocked('tochigi'), isFalse);
      if (id == 'tochigi') expect(u.isPrefectureUnlocked('gunma'), isFalse);
      await p.recordTestResult('$id/${id}_final', TestResult(21, 30, true, DateTime(2026, 10, 4)));
      expect(u.isPrefectureComplete(id), isTrue);
    }
    if (c.pack('saitama') != null) expect(u.isPrefectureUnlocked('saitama'), isTrue);
  });

  testWidgets('all thirteen locations and three readings open in the existing renderer', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    for (final id in ['ibaraki', 'tochigi', 'gunma']) {
      for (final lesson in services.catalog.pack(id)!.lessons.values) {
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
