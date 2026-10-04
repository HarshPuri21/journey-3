import '../core/json_reader.dart';

class StoryPage {
  const StoryPage({required this.text, this.en});
  final String text;
  final String? en;
}

/// A multi-page reading. Rendering a story screen comes in a later phase; the
/// data model and loading are in place so packs can already ship stories.
class Story {
  const Story({
    required this.id,
    required this.title,
    required this.pages,
    this.kanjiIds = const [],
    this.placeholder = false,
  });

  final String id;
  final String title;
  final List<StoryPage> pages;
  final List<String> kanjiIds;
  final bool placeholder;

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        id: reqStr(j, 'id', 'story'),
        title: reqStr(j, 'title', 'story'),
        placeholder: optBool(j, 'placeholder'),
        kanjiIds: strList(j, 'kanji'),
        pages: objList(j, 'pages')
            .map((p) => StoryPage(text: reqStr(p, 'text', 'story page'), en: optStr(p, 'en')))
            .toList(),
      );
}
