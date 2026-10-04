import '../package_system/journey_catalog.dart';
import '../package_system/pack_models.dart';
import '../core/ids.dart';
import '../progress/progress_service.dart';

/// Evaluates data-driven unlock rules against progress. There is no
/// per-prefecture logic anywhere: "Aomori needs Hokkaido" is just a rule in
/// Aomori's manifest.
class UnlockEvaluator {
  const UnlockEvaluator(this.catalog, this.progress);
  final JourneyCatalog catalog;
  final ProgressService progress;

  bool ruleSatisfied(UnlockRule r) {
    switch (r.type) {
      case 'prefectureComplete':
        return isPrefectureComplete(r.ref);
      case 'chapterComplete':
        final q = QualifiedId.tryParse(r.ref);
        return q != null && isChapterComplete(q.packId, q.localId);
      case 'lessonComplete':
        return progress.isLessonComplete(catalog.canonicalLessonId(r.ref));
      case 'testPassed':
        return progress.isTestPassed(r.ref);
      default:
        return false; // unknown rule types stay locked rather than crash
    }
  }

  bool allSatisfied(Iterable<UnlockRule> rules) => rules.every(ruleSatisfied);

  bool isPrefectureUnlocked(String prefectureId) {
    final pack = catalog.pack(prefectureId);
    return pack != null && allSatisfied(pack.manifest.unlock);
  }

  bool isPrefectureComplete(String prefectureId) {
    final pack = catalog.pack(prefectureId);
    if (pack == null) return false;
    if (pack.manifest.completion.isNotEmpty) return allSatisfied(pack.manifest.completion);
    final withLessons = pack.chapters.where((c) => pack.lessonsOf(c).isNotEmpty).toList();
    return withLessons.isNotEmpty && withLessons.every((c) => isChapterComplete(pack.id, c.id));
  }

  bool isReadingUnlocked(String packId) {
    final pack = catalog.pack(packId);
    final reading = pack?.manifest.reading;
    return pack != null && reading != null && isPrefectureUnlocked(packId) && allSatisfied(reading.unlock);
  }

  bool isTestUnlocked(String packId, String testId) {
    final pack = catalog.pack(packId);
    if (pack == null || !isPrefectureUnlocked(packId)) return false;
    for (final t in pack.manifest.tests) {
      if (t.id == testId) return allSatisfied(t.unlock);
    }
    return false;
  }

  bool isChapterComplete(String packId, String chapterId) {
    final pack = catalog.pack(packId);
    final chapter = pack?.chapter(chapterId);
    if (pack == null || chapter == null) return false;
    final lessons = pack.lessonsOf(chapter);
    return lessons.isNotEmpty && lessons.every((l) => progress.isLessonComplete(l.qualifiedId));
  }

  bool isChapterUnlocked(String packId, String chapterId) {
    final chapter = catalog.chapter(packId, chapterId);
    return chapter != null && isPrefectureUnlocked(packId) && allSatisfied(chapter.unlock);
  }

  bool isLessonUnlocked(String packId, String chapterId, String lessonId) {
    if (!isChapterUnlocked(packId, chapterId)) return false;
    final pack = catalog.pack(packId)!;
    final chapter = pack.chapter(chapterId)!;
    if (!chapter.sequential) return true;
    final lessons = pack.lessonsOf(chapter);
    final i = lessons.indexWhere((l) => l.id == lessonId);
    if (i < 0) return false;
    return i == 0 || progress.isLessonComplete(lessons[i - 1].qualifiedId);
  }
}
