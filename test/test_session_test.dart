import 'package:flutter_test/flutter_test.dart';
import 'package:n5_kanji_journey/package_system/journey_loader.dart';
import 'package:n5_kanji_journey/tests/test_session.dart';

import 'support/disk_pack_source.dart';

void main() {
  test('a session draws N questions from the bank; same seed, same session', () async {
    final catalog = await JourneyLoader(DiskPackSource()).load();
    final bank = catalog.knowledge.allQuestions;
    final def = catalog.pack('hokkaido')!.manifest.tests.single;
    expect(bank.length, greaterThan(def.questionCount));

    final a = TestSession.start(def, bank, seed: 7);
    final b = TestSession.start(def, bank, seed: 7);
    expect(a.questions, hasLength(def.questionCount));
    expect(a.questions.map((q) => q.id), b.questions.map((q) => q.id));
  });

  test('every attempt is balanced: 5 questions from each of the 6 categories', () async {
    final catalog = await JourneyLoader(DiskPackSource()).load();
    final def = catalog.pack('hokkaido')!.manifest.tests.single;
    for (var seed = 0; seed < 5; seed++) {
      final s = TestSession.start(def, catalog.pack('hokkaido')!.questions, seed: seed);
      expect(s.questions, hasLength(30));
      final byCat = <String, int>{};
      for (final q in s.questions) {
        byCat[q.category!] = (byCat[q.category!] ?? 0) + 1;
      }
      expect(byCat.values.toSet(), {5}, reason: 'seed $seed: $byCat');
      expect(s.questions.map((q) => q.id).toSet(), hasLength(30));
    }
  });

  test('a retake prefers questions the learner did not just see', () async {
    final catalog = await JourneyLoader(DiskPackSource()).load();
    final bank = catalog.pack('hokkaido')!.questions;
    final def = catalog.pack('hokkaido')!.manifest.tests.single;
    final first = TestSession.start(def, bank, seed: 1);
    final seen = first.questions.map((q) => q.id).toSet();
    // Quotas apply on retakes too. A category with fewer unseen questions
    // than its quota must repeat just enough questions to fill the gap.
    for (var seed = 0; seed < 10; seed++) {
      final second = TestSession.start(def, bank, seed: seed, avoid: seen);
      expect(second.questions, hasLength(def.questionCount));
      expect(second.questions.map((q) => q.id).toSet(), hasLength(def.questionCount));
      for (final quota in def.quotas.entries) {
        final unseen = bank.where((q) =>
            q.isMultipleChoice &&
            (def.tags.isEmpty || q.tags.any(def.tags.contains)) &&
            q.category == quota.key &&
            !seen.contains(q.id)).length;
        final minimumRepeats = unseen < quota.value ? quota.value - unseen : 0;
        final selected = second.questions.where((q) => q.category == quota.key);
        expect(selected, hasLength(quota.value));
        expect(selected.where((q) => seen.contains(q.id)), hasLength(minimumRepeats),
            reason: 'seed $seed, category ${quota.key} must prefer unseen questions');
      }
    }
  });

  test('missed questions expose the knowledge ids behind them', () async {
    final catalog = await JourneyLoader(DiskPackSource()).load();
    final def = catalog.pack('hokkaido')!.manifest.tests.single;
    final s = TestSession.start(def, catalog.pack('hokkaido')!.questions, seed: 3);
    expect(s.missed(const {}), hasLength(30));
    expect(s.missedRefs(const {}), isNotEmpty);
    expect(s.missedRefs({for (final q in s.questions) q.id: q.answerId}), isEmpty);
  });

  test('scoring and pass mark', () async {
    final catalog = await JourneyLoader(DiskPackSource()).load();
    final def = catalog.pack('hokkaido')!.manifest.tests.single;
    final s = TestSession.start(def, catalog.knowledge.allQuestions, seed: 1);

    final perfect = {for (final q in s.questions) q.id: q.answerId};
    expect(s.score(perfect), s.questions.length);
    expect(s.passed(s.score(perfect)), isTrue);
    expect(s.passed(0), isFalse);
  });
}
