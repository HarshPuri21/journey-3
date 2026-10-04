import 'dart:math';

import '../core/json_reader.dart';
import '../core/unlock_rule.dart';
import 'question.dart';

class TestDefinition {
  const TestDefinition({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.passRatio,
    this.tags = const [],
    this.quotas = const {},
    this.unlock = const [],
  });

  final String id;
  final String title;
  final int questionCount;
  final double passRatio;
  final List<String> tags;

  /// Optional balance: category -> how many questions of that category an
  /// attempt must contain (e.g. 5 per category for a 30-question test).
  final Map<String, int> quotas;
  final List<UnlockRule> unlock;

  factory TestDefinition.fromJson(Map<String, dynamic> j) {
    final q = j['quotas'];
    return TestDefinition(
      id: reqStr(j, 'id', 'test'),
      title: reqStr(j, 'title', 'test'),
      questionCount: reqInt(j, 'questionCount', 'test'),
      passRatio: reqNum(j, 'passRatio', 'test'),
      tags: strList(j, 'tags'),
      quotas: q is Map
          ? {for (final e in q.entries) if (e.value is int) '${e.key}': e.value as int}
          : const {},
      unlock: UnlockRule.list(j, 'unlock'),
    );
  }
}

/// One run of a test, drawn from a question bank. The bank is larger than the
/// test: every attempt draws [TestDefinition.questionCount] questions, honouring
/// the category quotas, and prefers questions that were NOT in the previous
/// attempt ([avoid]) so retakes change. Pass a seed for a reproducible draw.
class TestSession {
  TestSession._(this.definition, this.questions);

  final TestDefinition definition;
  final List<Question> questions;

  static TestSession start(
    TestDefinition def,
    Iterable<Question> bank, {
    int? seed,
    Set<String> avoid = const {},
  }) {
    final rnd = Random(seed);
    final pool = bank
        .where((q) => q.isMultipleChoice)
        .where((q) => def.tags.isEmpty || q.tags.any(def.tags.contains))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id)); // deterministic base order

    List<Question> draw(List<Question> candidates, int n) {
      final fresh = candidates.where((q) => !avoid.contains(q.id)).toList()..shuffle(rnd);
      final stale = candidates.where((q) => avoid.contains(q.id)).toList()..shuffle(rnd);
      return [...fresh, ...stale].take(n).toList();
    }

    final picked = <Question>[];
    if (def.quotas.isNotEmpty) {
      for (final e in def.quotas.entries) {
        picked.addAll(draw(pool.where((q) => q.category == e.key).toList(), e.value));
      }
    }
    if (picked.length < def.questionCount) {
      final rest = pool.where((q) => !picked.contains(q)).toList();
      picked.addAll(draw(rest, def.questionCount - picked.length));
    }
    picked.shuffle(rnd);
    return TestSession._(def, picked.take(def.questionCount).toList());
  }

  /// [answers] maps question id -> chosen choice id.
  int score(Map<String, String> answers) =>
      questions.where((q) => answers[q.id] == q.answerId).length;

  bool passed(int score) =>
      questions.isNotEmpty && score / questions.length >= definition.passRatio;

  List<Question> missed(Map<String, String> answers) =>
      questions.where((q) => answers[q.id] != q.answerId).toList();

  /// Knowledge ids behind the questions that were missed - the raw material
  /// for targeted review later.
  Set<String> missedRefs(Map<String, String> answers) => {for (final q in missed(answers)) ...q.refs};
}
