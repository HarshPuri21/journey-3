import '../core/json_reader.dart';

class Choice {
  const Choice(this.id, this.text);
  final String id;
  final String text;
}

/// A question in a pack's question bank. `type` is open-ended so new question
/// kinds can be added without breaking old banks (unknown types are skipped
/// by test sessions rather than crashing).
class Question {
  const Question({
    required this.id,
    required this.type,
    required this.prompt,
    required this.choices,
    required this.answerId,
    this.category,
    this.tags = const [],
    this.refs = const [],
    this.explanation,
  });

  final String id;
  final String type;
  final String prompt;
  final List<Choice> choices;
  final String answerId;

  /// Used by test quotas (e.g. 5 per category).
  final String? category;
  final List<String> tags;
  final List<String> refs;
  final String? explanation;

  bool get isMultipleChoice => type == 'multipleChoice';

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: reqStr(j, 'id', 'question'),
        type: reqStr(j, 'type', 'question'),
        prompt: reqStr(j, 'prompt', 'question'),
        choices: objList(j, 'choices')
            .map((c) => Choice(reqStr(c, 'id', 'choice'), reqStr(c, 'text', 'choice')))
            .toList(),
        answerId: reqStr(j, 'answer', 'question'),
        category: optStr(j, 'category'),
        tags: strList(j, 'tags'),
        refs: strList(j, 'refs'),
        explanation: optStr(j, 'explanation'),
      );
}
