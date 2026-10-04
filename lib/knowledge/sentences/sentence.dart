import '../../core/inline_markup.dart';
import '../../core/json_reader.dart';

class SentenceToken {
  const SentenceToken({required this.text, this.reading, this.gloss, this.vocabId, this.grammarId});
  final String text;
  final String? reading;
  final String? gloss;
  final String? vocabId;
  final String? grammarId;

  factory SentenceToken.fromJson(Map<String, dynamic> j) => SentenceToken(
        text: reqStr(j, 'text', 'token'),
        reading: optStr(j, 'reading'),
        gloss: optStr(j, 'gloss'),
        vocabId: optStr(j, 'vocab'),
        grammarId: optStr(j, 'grammar'),
      );
}

class Sentence {
  const Sentence({
    required this.id,
    required this.jp,
    required this.en,
    this.romaji,
    this.tokens = const [],
    this.grammarIds = const [],
    this.kanjiIds = const [],
  });

  final String id;

  /// Japanese with inline ruby markup, e.g. `{北海道|ほっかいどう}です。`
  final String jp;
  final String en;
  final String? romaji;
  final List<SentenceToken> tokens;
  final List<String> grammarIds;
  final List<String> kanjiIds;

  String get plainText => stripMarkup(jp);

  factory Sentence.fromJson(Map<String, dynamic> j) => Sentence(
        id: reqStr(j, 'id', 'sentence'),
        jp: reqStr(j, 'jp', 'sentence'),
        en: reqStr(j, 'en', 'sentence'),
        romaji: optStr(j, 'romaji'),
        tokens: objList(j, 'tokens').map(SentenceToken.fromJson).toList(),
        grammarIds: strList(j, 'grammar'),
        kanjiIds: strList(j, 'kanji'),
      );
}
