import 'package:flutter_test/flutter_test.dart';
import 'package:n5_kanji_journey/core/storage.dart';
import 'package:n5_kanji_journey/knowledge/knowledge_repository.dart';
import 'package:n5_kanji_journey/knowledge/knowledge_status.dart';
import 'package:n5_kanji_journey/package_system/journey_loader.dart';
import 'package:n5_kanji_journey/package_system/pack_models.dart';
import 'package:n5_kanji_journey/prefectures/unlock_evaluator.dart';
import 'package:n5_kanji_journey/progress/progress_service.dart';

import 'support/disk_pack_source.dart';

void main() {
  group('progress', () {
    test('persists across instances', () async {
      final storage = MemoryStorage();
      final a = ProgressService(storage);
      await a.load();
      await a.markLessonComplete('hokkaido/sapporo_l01');
      await a.saveCardPosition('hokkaido/sapporo_l01', 5);
      await a.recordTestResult('hokkaido/hokkaido_final', TestResult(4, 5, true, DateTime(2026, 10, 1)));

      final b = ProgressService(storage);
      await b.load();
      expect(b.isLessonComplete('hokkaido/sapporo_l01'), isTrue);
      expect(b.cardPosition('hokkaido/sapporo_l01'), 5);
      expect(b.isTestPassed('hokkaido/hokkaido_final'), isTrue);
      expect(b.testResults('hokkaido/hokkaido_final').single.score, 4);
    });

    test('a corrupt saved blob starts fresh instead of crashing', () async {
      final storage = MemoryStorage({ProgressService.storageKey: '{not json'});
      final p = ProgressService(storage);
      await p.load();
      expect(p.loaded, isTrue);
      expect(p.completedLessonIds, isEmpty);
    });

    test('progress for ids missing from the content is kept, never dropped', () async {
      final storage = MemoryStorage();
      final a = ProgressService(storage);
      await a.load();
      await a.markLessonComplete('atlantis/lost_l01');
      final b = ProgressService(storage);
      await b.load();
      expect(b.isLessonComplete('atlantis/lost_l01'), isTrue);
    });

    test('renamed lesson ids keep their progress through previousIds remapping', () async {
      final storage = MemoryStorage();
      final a = ProgressService(storage);
      await a.load();
      await a.markLessonComplete('hokkaido/old_name');
      final b = ProgressService(storage);
      await b.load(remapLessonId: (s) => s == 'hokkaido/old_name' ? 'hokkaido/new_name' : s);
      expect(b.isLessonComplete('hokkaido/new_name'), isTrue);
      expect(b.isLessonComplete('hokkaido/old_name'), isFalse);
    });
  });

  group('unlocking and knowledge status', () {
    test('chapters unlock from data rules and lessons follow chapter order', () async {
      final catalog = await JourneyLoader(DiskPackSource()).load();
      final progress = ProgressService(MemoryStorage());
      await progress.load();
      final u = UnlockEvaluator(catalog, progress);

      expect(u.isPrefectureUnlocked('hokkaido'), isTrue);
      expect(u.isChapterUnlocked('hokkaido', 'sapporo'), isTrue);
      expect(u.isChapterUnlocked('hokkaido', 'hakodate'), isFalse);
      expect(u.isLessonUnlocked('hokkaido', 'sapporo', 'sapporo_l01'), isTrue);

      await progress.markLessonComplete('hokkaido/sapporo_l01');
      expect(u.isChapterComplete('hokkaido', 'sapporo'), isTrue);
      expect(u.isChapterUnlocked('hokkaido', 'hakodate'), isTrue);
      expect(u.isChapterUnlocked('hokkaido', 'otaru'), isFalse);
    });

    test('unknown rule types stay locked instead of crashing', () async {
      final catalog = await JourneyLoader(DiskPackSource()).load();
      final progress = ProgressService(MemoryStorage());
      await progress.load();
      final u = UnlockEvaluator(catalog, progress);
      expect(u.ruleSatisfied(const UnlockRule('someFutureRule', 'x/y')), isFalse);
    });

    test('kanji go future -> encountered -> studied; encounter kanji stay encountered', () async {
      final catalog = await JourneyLoader(DiskPackSource()).load();
      final repo = catalog.knowledge;
      final progress = ProgressService(MemoryStorage());
      await progress.load();

      expect(kanjiStatus(repo, progress, 'kanji_北'), KnowledgeStatus.future);
      await progress.markLessonStarted('hokkaido/sapporo_l01');
      expect(kanjiStatus(repo, progress, 'kanji_北'), KnowledgeStatus.encountered);
      expect(kanjiStatus(repo, progress, 'kanji_河'), KnowledgeStatus.encountered);

      await progress.markLessonComplete('hokkaido/sapporo_l01');
      expect(kanjiStatus(repo, progress, 'kanji_北'), KnowledgeStatus.studied);
      expect(kanjiStatus(repo, progress, 'kanji_札'), KnowledgeStatus.encountered);
    });
  });

  group('knowledge cross-links', () {
    test('radicals link to every kanji that uses them', () async {
      final repo = (await JourneyLoader(DiskPackSource()).load()).knowledge;
      expect(repo.kanjiUsingRadical('radical_sanzui').map((k) => k.char), containsAll(['海', '河', '池', '湖']));
      expect(repo.kanjiUsingRadical('radical_shinnyou').map((k) => k.char), containsAll(['道', '近', '通', '遠']));
    });

    test('vocabulary, sentences and lessons are derived from one kanji id', () async {
      final repo = (await JourneyLoader(DiskPackSource()).load()).knowledge;
      expect(repo.vocabularyUsingKanji('kanji_北').map((v) => v.id), containsAll(['vocab_北海道', 'vocab_北部', 'vocab_北']));
      expect(repo.sentencesUsingKanji('kanji_北').isNotEmpty, isTrue);
      final roles = {for (final a in repo.lessonsForKanji('kanji_札')) a.role};
      expect(roles, contains(LessonRole.encounter));
    });
  });
}
