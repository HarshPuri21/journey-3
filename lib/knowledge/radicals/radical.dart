import '../../core/json_reader.dart';

/// A radical / component as a first-class entity. `exampleKanji` is authored
/// data; the repository also derives "every kanji that lists me as a
/// component", so connections appear even for kanji not yet studied.
class Radical {
  const Radical({
    required this.id,
    required this.char,
    required this.name,
    required this.meanings,
    this.nameRomaji,
    this.note,
    this.exampleKanji = const [],
  });

  final String id;
  final String char;
  final String name;
  final String? nameRomaji;
  final List<String> meanings;
  final String? note;
  final List<String> exampleKanji;

  factory Radical.fromJson(Map<String, dynamic> j) => Radical(
        id: reqStr(j, 'id', 'radical'),
        char: reqStr(j, 'char', 'radical'),
        name: reqStr(j, 'name', 'radical'),
        nameRomaji: optStr(j, 'nameRomaji'),
        meanings: strList(j, 'meanings'),
        note: optStr(j, 'note'),
        exampleKanji: strList(j, 'exampleKanji'),
      );
}
