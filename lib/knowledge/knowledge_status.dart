import '../progress/progress_service.dart';
import 'knowledge_repository.dart';

/// 学習 studied / 出会い encountered / 未来 future - the three states from the
/// curriculum. Derived from progress; never stored.
enum KnowledgeStatus { studied, encountered, future }

KnowledgeStatus kanjiStatus(KnowledgeRepository repo, ProgressService progress, String kanjiId) {
  var encountered = false;
  for (final a in repo.lessonsForKanji(kanjiId)) {
    if (a.role == LessonRole.core && progress.isLessonComplete(a.lessonQualifiedId)) {
      return KnowledgeStatus.studied;
    }
    if (progress.isLessonStarted(a.lessonQualifiedId)) encountered = true;
  }
  return encountered ? KnowledgeStatus.encountered : KnowledgeStatus.future;
}
