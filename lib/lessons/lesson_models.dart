import '../core/json_reader.dart';

/// One piece of lesson content. Blocks are deliberately generic (a type plus a
/// data map): new block types only need a renderer registered, never a model
/// change, and unknown types degrade to a placeholder instead of failing.
class ContentBlock {
  const ContentBlock(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;

  String? str(String key) => optStr(data, key);
  List<String> strings(String key) => strList(data, key);
  bool flag(String key, {bool or = false}) => optBool(data, key, or: or);
  int? integer(String key) => optInt(data, key);
}

class LessonCard {
  const LessonCard({
    required this.id,
    required this.title,
    required this.blocks,
    this.kind = 'content',
    this.scroll = false,
  });

  final String id;
  final String title;
  final String kind;

  /// True for long cards (e.g. "Things to Remember"): content starts at the
  /// top and scrolls. Other cards are centred when they fit on screen.
  final bool scroll;
  final List<ContentBlock> blocks;

  factory LessonCard.fromJson(Map<String, dynamic> j) => LessonCard(
        id: reqStr(j, 'id', 'card'),
        title: reqStr(j, 'title', 'card'),
        kind: optStr(j, 'kind') ?? 'content',
        scroll: optBool(j, 'scroll'),
        blocks: objList(j, 'blocks')
            .map((b) => ContentBlock(optStr(b, 'type') ?? 'unknown', b))
            .toList(),
      );
}

class LessonCompletion {
  const LessonCompletion({required this.title, this.nextText, this.nextChapter});
  final String title;
  final String? nextText;

  /// Qualified chapter id (`packId/chapterId`), optional.
  final String? nextChapter;
}

class Lesson {
  const Lesson({
    required this.packId,
    required this.id,
    required this.number,
    required this.title,
    required this.cards,
    this.goal,
    this.estimatedMinutes,
    this.coreKanjiIds = const [],
    this.encounterKanjiIds = const [],
    this.previousIds = const [],
    this.completion,
    this.isDraft = false,
  });

  final String packId;
  final String id;
  final int number;
  final String title;
  final String? goal;
  final int? estimatedMinutes;
  final List<String> coreKanjiIds;
  final List<String> encounterKanjiIds;
  final List<String> previousIds;
  final List<LessonCard> cards;
  final LessonCompletion? completion;

  /// A placeholder lesson that still needs its real content.
  final bool isDraft;

  /// Stable global key used by progress: `packId/lessonId`.
  String get qualifiedId => '$packId/$id';

  factory Lesson.fromJson(String packId, Map<String, dynamic> j) {
    final c = j['completion'];
    LessonCompletion? completion;
    if (c is Map) {
      final cm = Map<String, dynamic>.from(c);
      completion = LessonCompletion(
        title: optStr(cm, 'title') ?? 'Lesson complete',
        nextText: optStr(cm, 'nextText'),
        nextChapter: optStr(cm, 'nextChapter'),
      );
    }
    return Lesson(
      packId: packId,
      id: reqStr(j, 'id', 'lesson'),
      number: optInt(j, 'number') ?? 0,
      title: reqStr(j, 'title', 'lesson'),
      goal: optStr(j, 'goal'),
      estimatedMinutes: optInt(j, 'estimatedMinutes'),
      coreKanjiIds: strList(j, 'coreKanji'),
      encounterKanjiIds: strList(j, 'encounterKanji'),
      previousIds: strList(j, 'previousIds'),
      cards: objList(j, 'cards').map(LessonCard.fromJson).toList(),
      completion: completion,
      isDraft: optStr(j, 'status') == 'draft',
    );
  }
}
