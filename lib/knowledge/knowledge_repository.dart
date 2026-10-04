import 'grammar/grammar.dart';
import 'kanji/kanji.dart';
import 'radicals/radical.dart';
import 'sentences/sentence.dart';
import 'vocabulary/vocabulary.dart';
import '../package_system/pack_models.dart';
import '../stories/story.dart';
import '../tests/question.dart';

enum LessonRole { core, encounter, referenced }

class LessonAppearance {
  const LessonAppearance(this.lessonQualifiedId, this.role);
  final String lessonQualifiedId;
  final LessonRole role;
}

/// The data boundary between the Journey engine and wherever knowledge comes
/// from. Today: [InMemoryKnowledgeRepository] built from content packs. Later:
/// an adapter over the main app's database can implement the same interface -
/// the engine never needs to know.
abstract class KnowledgeRepository {
  Kanji? kanji(String id);
  Radical? radical(String id);
  Vocabulary? vocabulary(String id);
  GrammarPoint? grammar(String id);
  Sentence? sentence(String id);
  Story? story(String id);
  Question? question(String id);

  Iterable<Kanji> get allKanji;
  Iterable<Question> get allQuestions;

  // Derived, cross-linked views.
  List<Kanji> kanjiUsingRadical(String radicalId);
  List<Vocabulary> vocabularyUsingKanji(String kanjiId);
  List<Sentence> sentencesUsingKanji(String kanjiId);
  List<LessonAppearance> lessonsForKanji(String kanjiId);
}

class InMemoryKnowledgeRepository implements KnowledgeRepository {
  InMemoryKnowledgeRepository(Iterable<LoadedPack> packs, {List<String>? diagnostics}) {
    final diag = diagnostics ?? <String>[];
    for (final p in packs) {
      _put(_kanji, p.kanji, (e) => e.id, 'kanji', p.id, diag);
      _put(_radicals, p.radicals, (e) => e.id, 'radical', p.id, diag);
      _put(_vocab, p.vocabulary, (e) => e.id, 'vocabulary', p.id, diag);
      _put(_grammar, p.grammar, (e) => e.id, 'grammar', p.id, diag);
      _put(_sentences, p.sentences, (e) => e.id, 'sentence', p.id, diag);
      _put(_stories, p.stories, (e) => e.id, 'story', p.id, diag);
      _put(_questions, p.questions, (e) => e.id, 'question', p.id, diag);
    }
    _buildIndexes(packs);
  }

  final Map<String, Kanji> _kanji = {};
  final Map<String, Radical> _radicals = {};
  final Map<String, Vocabulary> _vocab = {};
  final Map<String, GrammarPoint> _grammar = {};
  final Map<String, Sentence> _sentences = {};
  final Map<String, Story> _stories = {};
  final Map<String, Question> _questions = {};

  final Map<String, List<Kanji>> _kanjiByRadical = {};
  final Map<String, List<Vocabulary>> _vocabByKanji = {};
  final Map<String, List<Sentence>> _sentencesByKanji = {};
  final Map<String, List<LessonAppearance>> _lessonsByKanji = {};

  static void _put<T>(Map<String, T> into, List<T> items, String Function(T) idOf, String what,
      String packId, List<String> diag) {
    for (final it in items) {
      final id = idOf(it);
      if (into.containsKey(id)) {
        diag.add('pack "$packId": duplicate $what id "$id" ignored');
      } else {
        into[id] = it;
      }
    }
  }

  void _buildIndexes(Iterable<LoadedPack> packs) {
    for (final k in _kanji.values) {
      for (final c in k.components) {
        _kanjiByRadical.putIfAbsent(c.radicalId, () => []).add(k);
      }
    }
    // Radicals may also list example kanji that don't list the radical back.
    for (final r in _radicals.values) {
      for (final id in r.exampleKanji) {
        final k = _kanji[id];
        final list = _kanjiByRadical.putIfAbsent(r.id, () => []);
        if (k != null && !list.contains(k)) list.add(k);
      }
    }
    for (final v in _vocab.values) {
      for (final id in v.kanjiIds) {
        _vocabByKanji.putIfAbsent(id, () => []).add(v);
      }
    }
    for (final s in _sentences.values) {
      for (final id in s.kanjiIds) {
        _sentencesByKanji.putIfAbsent(id, () => []).add(s);
      }
    }
    for (final p in packs) {
      for (final l in p.lessons.values) {
        final seen = <String>{};
        void add(String kanjiId, LessonRole role) {
          if (seen.add('$kanjiId|${role.name}')) {
            _lessonsByKanji
                .putIfAbsent(kanjiId, () => [])
                .add(LessonAppearance(l.qualifiedId, role));
          }
        }

        for (final id in l.coreKanjiIds) {
          add(id, LessonRole.core);
        }
        for (final id in l.encounterKanjiIds) {
          add(id, LessonRole.encounter);
        }
        for (final card in l.cards) {
          for (final b in card.blocks) {
            final id = b.str('id');
            if (b.type == 'kanjiRef' && id != null) add(id, LessonRole.referenced);
            if (b.type == 'kanjiRow') {
              for (final k in b.strings('ids')) {
                add(k, LessonRole.referenced);
              }
            }
          }
        }
      }
    }
  }

  @override
  Kanji? kanji(String id) => _kanji[id];
  @override
  Radical? radical(String id) => _radicals[id];
  @override
  Vocabulary? vocabulary(String id) => _vocab[id];
  @override
  GrammarPoint? grammar(String id) => _grammar[id];
  @override
  Sentence? sentence(String id) => _sentences[id];
  @override
  Story? story(String id) => _stories[id];
  @override
  Question? question(String id) => _questions[id];

  @override
  Iterable<Kanji> get allKanji => _kanji.values;
  @override
  Iterable<Question> get allQuestions => _questions.values;

  @override
  List<Kanji> kanjiUsingRadical(String radicalId) => _kanjiByRadical[radicalId] ?? const [];
  @override
  List<Vocabulary> vocabularyUsingKanji(String kanjiId) => _vocabByKanji[kanjiId] ?? const [];
  @override
  List<Sentence> sentencesUsingKanji(String kanjiId) => _sentencesByKanji[kanjiId] ?? const [];
  @override
  List<LessonAppearance> lessonsForKanji(String kanjiId) => _lessonsByKanji[kanjiId] ?? const [];
}
