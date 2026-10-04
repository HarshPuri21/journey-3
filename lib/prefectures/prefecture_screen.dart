import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/journey_scaffold.dart';
import '../chapters/chapter_screen.dart';
import '../lessons/lesson_screen.dart';
import '../map/node_map.dart';
import '../navigation/journey_routes.dart';
import '../package_system/journey_catalog.dart';
import '../package_system/pack_models.dart';
import '../progress/progress_service.dart';
import '../tests/test_screen.dart';
import 'unlock_evaluator.dart';

/// Prefecture level: the mini-map of chapters/locations, then the two things
/// that conclude every prefecture - the Reading Journey and the Test.
class PrefectureScreen extends StatelessWidget {
  const PrefectureScreen({super.key, required this.prefectureId});
  final String prefectureId;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<JourneyCatalog>();
    final progress = context.watch<ProgressService>();
    final unlocks = UnlockEvaluator(catalog, progress);
    final entry = catalog.prefecture(prefectureId);
    final pack = catalog.pack(prefectureId);
    if (entry == null || pack == null) {
      return JourneyScaffold(title: prefectureId, body: const Center(child: Text('This prefecture is not installed.')));
    }

    final chapters = pack.chapters;
    final nodes = <MapNode>[];
    for (var i = 0; i < chapters.length; i++) {
      final c = chapters[i];
      final NodeState state;
      if (unlocks.isChapterComplete(pack.id, c.id)) {
        state = NodeState.completed;
      } else if (unlocks.isChapterUnlocked(pack.id, c.id)) {
        state = NodeState.available;
      } else {
        state = NodeState.locked;
      }
      nodes.add(MapNode(
        id: c.id,
        number: i + 1, // display only - never used as an identifier
        label: c.name,
        sublabel: c.nameEn,
        position: c.map ?? MapPoint(0.5, (i + 1) / (chapters.length + 1)),
        state: state,
      ));
    }

    void say(String message) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    void onTap(MapNode n) {
      if (n.state == NodeState.locked) {
        say('${n.sublabel ?? n.label} is locked - finish the previous location first.');
        return;
      }
      zoomInTo<void>(context, ChapterScreen(packId: pack.id, chapterId: n.id));
    }

    final cover = pack.manifest.cover;
    final criteria = pack.manifest.completionCriteria;
    final readingRef = pack.manifest.reading;
    final readingLesson = pack.readingLesson;

    return JourneyScaffold(
      title: '${entry.route.name}  ${entry.route.nameEn}',
      actions: [
        if (criteria.isNotEmpty)
          IconButton(
            key: const ValueKey('goals-button'),
            tooltip: 'What you will be able to do',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('After ${entry.route.nameEn}'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in criteria)
                        ListTile(dense: true, leading: const Icon(Icons.check_circle_outline, size: 18), title: Text(c)),
                    ],
                  ),
                ),
                actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
              ),
            ),
          ),
      ],
      body: Column(
        children: [
          if (cover != null)
            SizedBox(
              height: 84,
              width: double.infinity,
              child: Image.asset(
                'content/packs/${pack.id}/$cover',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Expanded(child: NodeMapView(nodes: nodes, onTap: onTap, aspectRatio: 0.7)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  if (readingRef != null && readingLesson != null)
                    Expanded(
                      child: _ActionCard(
                        key: const ValueKey('reading-tile'),
                        icon: progress.isLessonComplete(readingLesson.qualifiedId)
                            ? Icons.check_circle
                            : (unlocks.isReadingUnlocked(pack.id) ? Icons.menu_book_outlined : Icons.lock_outline),
                        title: readingRef.title,
                        subtitle: '${readingLesson.cards.length} cards',
                        onTap: () {
                          if (unlocks.isReadingUnlocked(pack.id)) {
                            slideTo<bool>(context, LessonScreen(lesson: readingLesson));
                          } else {
                            say('Finish all the location lessons to unlock the reading.');
                          }
                        },
                      ),
                    ),
                  for (final t in pack.manifest.tests)
                    Expanded(
                      child: _ActionCard(
                        key: ValueKey('test-${t.id}'),
                        icon: progress.isTestPassed('${pack.id}/${t.id}')
                            ? Icons.check_circle
                            : (unlocks.isTestUnlocked(pack.id, t.id) ? Icons.quiz_outlined : Icons.lock_outline),
                        title: t.title,
                        subtitle: _testSubtitle(progress, pack.id, t.id, t.questionCount),
                        onTap: () {
                          if (unlocks.isTestUnlocked(pack.id, t.id)) {
                            slideTo<void>(context, TestScreen(packId: pack.id, testId: t.id));
                          } else {
                            say('Finish the reading journey to unlock the test.');
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _testSubtitle(ProgressService progress, String packId, String testId, int count) {
    final results = progress.testResults('$packId/$testId');
    if (results.isEmpty) return '$count questions';
    var best = results.first;
    for (final r in results) {
      if (r.score > best.score) best = r;
    }
    return '${best.passed ? 'Passed' : 'Best'} ${best.score}/${best.total}';
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: t.labelLarge),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
