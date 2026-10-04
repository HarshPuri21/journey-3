import '../core/json_reader.dart';
import '../core/unlock_rule.dart';
import '../knowledge/grammar/grammar.dart';
import '../knowledge/kanji/kanji.dart';
import '../knowledge/radicals/radical.dart';
import '../knowledge/sentences/sentence.dart';
import '../knowledge/vocabulary/vocabulary.dart';
import '../lessons/lesson_models.dart';
import '../stories/story.dart';
import '../tests/question.dart';
import '../tests/test_session.dart';

export '../core/unlock_rule.dart';

class MapPoint {
  const MapPoint(this.x, this.y);
  final double x; // 0..1 left -> right
  final double y; // 0..1 top -> bottom

  static MapPoint? tryParse(Object? v) {
    if (v is Map && v['x'] is num && v['y'] is num) {
      return MapPoint((v['x'] as num).toDouble(), (v['y'] as num).toDouble());
    }
    return null;
  }
}

/// The cumulative reading module of a prefecture. It is a normal lesson
/// document (cards of blocks), so the lesson screen renders it unchanged.
class ReadingRef {
  const ReadingRef({required this.id, required this.title, required this.file, required this.unlock});
  final String id;
  final String title;
  final String file;
  final List<UnlockRule> unlock;
}

class RouteEntry {
  const RouteEntry({
    required this.prefectureId,
    required this.number,
    required this.name,
    required this.nameEn,
    required this.map,
    this.nameReading,
  });
  final String prefectureId;
  final int number;
  final String name;
  final String nameEn;
  final String? nameReading;
  final MapPoint map;
}

/// The ordered route of the whole Journey. Order = list order (curriculum
/// data), never alphabetical. Entries without an installed pack are shown as
/// "coming later".
class JourneyIndex {
  const JourneyIndex({required this.journeyId, required this.title, required this.route});
  final String journeyId;
  final String title;
  final List<RouteEntry> route;

  factory JourneyIndex.fromJson(Map<String, dynamic> j) => JourneyIndex(
        journeyId: reqStr(j, 'journeyId', 'index'),
        title: reqStr(j, 'title', 'index'),
        route: objList(j, 'route').map((r) {
          return RouteEntry(
            prefectureId: reqStr(r, 'prefectureId', 'route'),
            number: reqInt(r, 'number', 'route'),
            name: reqStr(r, 'name', 'route'),
            nameEn: reqStr(r, 'nameEn', 'route'),
            nameReading: optStr(r, 'nameReading'),
            map: MapPoint.tryParse(r['map']) ?? const MapPoint(0.5, 0.5),
          );
        }).toList(growable: false),
      );
}

class ChapterRef {
  const ChapterRef(this.id, this.file, this.map);
  final String id;
  final String file;
  final MapPoint? map;
}

class PackManifest {
  const PackManifest({
    required this.packId,
    required this.type,
    required this.contentVersion,
    required this.engineSchemaMin,
    required this.title,
    required this.dependencies,
    required this.unlock,
    required this.completion,
    required this.chapters,
    required this.tests,
    this.titleEn,
    this.cover,
    this.knowledge = const {},
    this.questionBank,
    this.reading,
    this.completionCriteria = const [],
  });

  final String packId;
  final String type; // 'prefecture' | 'knowledge'
  final int contentVersion;
  final int engineSchemaMin;
  final String title;
  final String? titleEn;
  final String? cover;
  final List<String> dependencies;
  final List<UnlockRule> unlock;
  final List<UnlockRule> completion;
  final List<ChapterRef> chapters;
  final Map<String, String> knowledge;
  final String? questionBank;
  final List<TestDefinition> tests;
  final ReadingRef? reading;
  final List<String> completionCriteria;

  String get displayTitle => titleEn ?? title;

  factory PackManifest.fromJson(Map<String, dynamic> j) {
    final k = j['knowledge'];
    return PackManifest(
      packId: reqStr(j, 'packId', 'manifest'),
      type: optStr(j, 'type') ?? 'prefecture',
      contentVersion: optInt(j, 'contentVersion') ?? 1,
      engineSchemaMin: optInt(j, 'engineSchemaMin') ?? 1,
      title: reqStr(j, 'title', 'manifest'),
      titleEn: optStr(j, 'titleEn'),
      cover: optStr(j, 'cover'),
      dependencies: strList(j, 'dependencies'),
      unlock: UnlockRule.list(j, 'unlock'),
      completion: UnlockRule.list(j, 'completion'),
      chapters: objList(j, 'chapters')
          .map((c) => ChapterRef(reqStr(c, 'id', 'chapter ref'), reqStr(c, 'file', 'chapter ref'),
              MapPoint.tryParse(c['map'])))
          .toList(growable: false),
      knowledge: k is Map
          ? {for (final e in k.entries) if (e.value is String) e.key as String: e.value as String}
          : const {},
      questionBank: optStr(j, 'questionBank'),
      tests: objList(j, 'tests').map(TestDefinition.fromJson).toList(growable: false),
      completionCriteria: strList(j, 'completionCriteria'),
      reading: j['reading'] is Map
          ? () {
              final r = asMap(j['reading'], 'reading');
              return ReadingRef(
                id: reqStr(r, 'id', 'reading'),
                title: reqStr(r, 'title', 'reading'),
                file: reqStr(r, 'file', 'reading'),
                unlock: UnlockRule.list(r, 'unlock'),
              );
            }()
          : null,
    );
  }
}

class LessonRef {
  const LessonRef(this.id, this.file);
  final String id;
  final String file;
}

class Chapter {
  const Chapter({
    required this.packId,
    required this.id,
    required this.name,
    required this.lessonRefs,
    required this.unlock,
    this.nameEn,
    this.reading,
    this.summary,
    this.sequential = true,
    this.map,
  });

  final String packId;
  final String id;
  final String name;
  final String? nameEn;
  final String? reading;
  final String? summary;
  final bool sequential;
  final List<LessonRef> lessonRefs;
  final List<UnlockRule> unlock;
  final MapPoint? map;

  String get qualifiedId => '$packId/$id';
}

/// Everything one pack contributes, fully parsed.
class LoadedPack {
  LoadedPack({
    required this.manifest,
    required this.chapters,
    required this.lessons,
    this.kanji = const [],
    this.radicals = const [],
    this.vocabulary = const [],
    this.grammar = const [],
    this.sentences = const [],
    this.stories = const [],
    this.questions = const [],
  });

  final PackManifest manifest;
  final List<Chapter> chapters;
  final Map<String, Lesson> lessons; // by local lesson id
  final List<Kanji> kanji;
  final List<Radical> radicals;
  final List<Vocabulary> vocabulary;
  final List<GrammarPoint> grammar;
  final List<Sentence> sentences;
  final List<Story> stories;
  final List<Question> questions;

  String get id => manifest.packId;

  /// The prefecture's reading module, if the manifest declares one and it loaded.
  Lesson? get readingLesson {
    final r = manifest.reading;
    return r == null ? null : lessons[r.id];
  }

  Chapter? chapter(String id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Lesson> lessonsOf(Chapter c) =>
      c.lessonRefs.map((r) => lessons[r.id]).whereType<Lesson>().toList(growable: false);
}
