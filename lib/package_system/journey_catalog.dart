import '../knowledge/knowledge_repository.dart';
import '../lessons/lesson_models.dart';
import 'pack_models.dart';

class LoadDiagnostic {
  const LoadDiagnostic(this.scope, this.message);
  final String scope;
  final String message;
  @override
  String toString() => '[$scope] $message';
}

/// One stop on the route: the curriculum's entry plus (maybe) its installed pack.
class PrefectureEntry {
  const PrefectureEntry(this.route, this.pack);
  final RouteEntry route;
  final LoadedPack? pack;
  String get id => route.prefectureId;
  bool get installed => pack != null;
}

/// Everything the engine knows about installed content. Built once by
/// [JourneyLoader]; immutable afterwards. Works with zero, one or all packs.
class JourneyCatalog {
  JourneyCatalog({
    required this.index,
    required Map<String, LoadedPack> packs,
    required this.knowledge,
    required this.diagnostics,
  }) : _packs = Map.unmodifiable(packs) {
    for (final p in packs.values) {
      for (final l in p.lessons.values) {
        for (final old in l.previousIds) {
          _lessonAliases['${p.id}/$old'] = l.qualifiedId;
        }
      }
    }
  }

  final JourneyIndex index;
  final KnowledgeRepository knowledge;
  final List<LoadDiagnostic> diagnostics;
  final Map<String, LoadedPack> _packs;
  final Map<String, String> _lessonAliases = {};

  Iterable<LoadedPack> get packs => _packs.values;
  LoadedPack? pack(String id) => _packs[id];

  /// The route in curriculum order; absent packs appear as "coming later".
  List<PrefectureEntry> get prefectures =>
      [for (final r in index.route) PrefectureEntry(r, _packs[r.prefectureId])];

  PrefectureEntry? prefecture(String id) {
    for (final p in prefectures) {
      if (p.id == id) return p;
    }
    return null;
  }

  Chapter? chapter(String packId, String chapterId) => _packs[packId]?.chapter(chapterId);

  Lesson? lesson(String packId, String lessonId) => _packs[packId]?.lessons[lessonId];

  Lesson? lessonByQualifiedId(String qualified) {
    final i = qualified.indexOf('/');
    if (i <= 0) return null;
    return lesson(qualified.substring(0, i), qualified.substring(i + 1));
  }

  /// Follows `previousIds` renames so saved progress survives curriculum edits.
  String canonicalLessonId(String qualified) => _lessonAliases[qualified] ?? qualified;
}
