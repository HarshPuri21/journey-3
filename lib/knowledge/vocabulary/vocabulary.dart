import '../../core/json_reader.dart';

class Vocabulary {
  const Vocabulary({
    required this.id,
    required this.word,
    required this.reading,
    required this.meanings,
    this.pos,
    this.kanjiIds = const [],
    this.exampleSentenceIds = const [],
  });

  final String id;
  final String word;
  final String reading;
  final List<String> meanings;
  final String? pos;
  final List<String> kanjiIds;
  final List<String> exampleSentenceIds;

  factory Vocabulary.fromJson(Map<String, dynamic> j) => Vocabulary(
        id: reqStr(j, 'id', 'vocabulary'),
        word: reqStr(j, 'word', 'vocabulary'),
        reading: reqStr(j, 'reading', 'vocabulary'),
        meanings: strList(j, 'meanings'),
        pos: optStr(j, 'pos'),
        kanjiIds: strList(j, 'kanji'),
        exampleSentenceIds: strList(j, 'exampleSentences'),
      );
}
