import 'json_reader.dart';

/// A data-driven unlock/completion condition. Unknown `type`s are kept and
/// simply evaluate to "not satisfied", so future rule types never crash an
/// older app.
class UnlockRule {
  const UnlockRule(this.type, this.ref);
  final String type;
  final String ref;

  factory UnlockRule.fromJson(Map<String, dynamic> j) =>
      UnlockRule(reqStr(j, 'type', 'rule'), reqStr(j, 'ref', 'rule'));

  static List<UnlockRule> list(Map<String, dynamic> j, String key) =>
      objList(j, key).map(UnlockRule.fromJson).toList(growable: false);
}
