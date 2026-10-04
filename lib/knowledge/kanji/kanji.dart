import '../../core/json_reader.dart';

enum ComponentRole { meaning, sound, classifier, shape, unknown }

class KanjiComponent {
  const KanjiComponent(this.radicalId, this.role, this.note);
  final String radicalId;
  final ComponentRole role;
  final String? note;

  factory KanjiComponent.fromJson(Map<String, dynamic> j) {
    final r = optStr(j, 'role');
    return KanjiComponent(
      reqStr(j, 'radical', 'component'),
      ComponentRole.values.firstWhere((e) => e.name == r, orElse: () => ComponentRole.unknown),
      optStr(j, 'note'),
    );
  }
}

/// A reusable kanji knowledge entity. Lessons reference it by [id]; they never
/// copy it. "Where is it taught / which radicals / which words" are derived
/// indexes (see KnowledgeRepository), not stored here.
class Kanji {
  const Kanji({
    required this.id,
    required this.char,
    required this.meanings,
    this.onyomi = const [],
    this.kunyomi = const [],
    this.components = const [],
    this.relatedKanji = const [],
    this.notes,
  });

  final String id;
  final String char;
  final List<String> meanings;
  final List<String> onyomi;
  final List<String> kunyomi;
  final List<KanjiComponent> components;
  final List<String> relatedKanji;
  final String? notes;

  factory Kanji.fromJson(Map<String, dynamic> j) => Kanji(
        id: reqStr(j, 'id', 'kanji'),
        char: reqStr(j, 'char', 'kanji'),
        meanings: strList(j, 'meanings'),
        onyomi: strList(j, 'onyomi'),
        kunyomi: strList(j, 'kunyomi'),
        components: objList(j, 'components').map(KanjiComponent.fromJson).toList(),
        relatedKanji: strList(j, 'relatedKanji'),
        notes: optStr(j, 'notes'),
      );
}
