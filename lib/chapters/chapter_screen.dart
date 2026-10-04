import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/journey_scaffold.dart';
import '../lessons/lesson_models.dart';
import '../lessons/lesson_screen.dart';
import '../navigation/journey_routes.dart';
import '../package_system/journey_catalog.dart';
import '../prefectures/unlock_evaluator.dart';
import '../progress/progress_service.dart';

/// Chapter/location level: the lessons of one place.
class ChapterScreen extends StatelessWidget {
  const ChapterScreen({super.key, required this.packId, required this.chapterId});
  final String packId;
  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<JourneyCatalog>();
    final progress = context.watch<ProgressService>();
    final unlocks = UnlockEvaluator(catalog, progress);
    final pack = catalog.pack(packId);
    final chapter = pack?.chapter(chapterId);
    if (pack == null || chapter == null) {
      return JourneyScaffold(title: chapterId, body: const Center(child: Text('This location is not available.')));
    }
    final lessons = pack.lessonsOf(chapter);
    final t = Theme.of(context).textTheme;
    return JourneyScaffold(
      title: '${chapter.name}  ${chapter.nameEn ?? ''}'.trim(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (chapter.reading != null) Text(chapter.reading!, style: t.titleMedium),
          if (chapter.summary != null) Padding(padding: const EdgeInsets.only(top: 4, bottom: 12), child: Text(chapter.summary!)),
          if (lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Lessons for this location are coming soon.')),
            ),
          for (final l in lessons) _LessonTile(lesson: l, unlocked: unlocks.isLessonUnlocked(packId, chapterId, l.id)),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.unlocked});
  final Lesson lesson;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressService>();
    final done = progress.isLessonComplete(lesson.qualifiedId);
    final icon = done ? Icons.check_circle : (unlocked ? Icons.play_circle_outline : Icons.lock_outline);
    return Card(
      key: ValueKey('lesson-${lesson.id}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        enabled: unlocked,
        leading: Icon(icon),
        title: Text('Lesson ${lesson.number}: ${lesson.title}${lesson.isDraft ? '  (draft)' : ''}'),
        subtitle: Text([
          if (lesson.goal != null) lesson.goal!,
          if (lesson.estimatedMinutes != null) '~${lesson.estimatedMinutes} min',
        ].join('\n')),
        isThreeLine: lesson.goal != null,
        onTap: unlocked ? () => slideTo<bool>(context, LessonScreen(lesson: lesson)) : null,
      ),
    );
  }
}
