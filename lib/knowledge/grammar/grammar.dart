import '../../core/json_reader.dart';

class GrammarPoint {
  const GrammarPoint({required this.id, required this.title, required this.explanation, this.pattern});
  final String id;
  final String title;
  final String? pattern;
  final String explanation;

  factory GrammarPoint.fromJson(Map<String, dynamic> j) => GrammarPoint(
        id: reqStr(j, 'id', 'grammar'),
        title: reqStr(j, 'title', 'grammar'),
        pattern: optStr(j, 'pattern'),
        explanation: reqStr(j, 'explanation', 'grammar'),
      );
}
