/// Thrown when a content document does not have the expected shape.
/// The loader catches these per pack/file, records a [LoadDiagnostic] and
/// carries on - bad content must never crash the app.
class ContentFormatException implements Exception {
  ContentFormatException(this.message);
  final String message;
  @override
  String toString() => 'ContentFormatException: $message';
}

Map<String, dynamic> asMap(Object? v, String where) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  throw ContentFormatException('$where: expected an object');
}

List<dynamic> asList(Object? v, String where) {
  if (v is List) return v;
  throw ContentFormatException('$where: expected a list');
}

String reqStr(Map<String, dynamic> m, String key, String where) {
  final v = m[key];
  if (v is String) return v;
  throw ContentFormatException('$where: missing string "$key"');
}

String? optStr(Map<String, dynamic> m, String key) {
  final v = m[key];
  return v is String ? v : null;
}

int reqInt(Map<String, dynamic> m, String key, String where) {
  final v = m[key];
  if (v is int) return v;
  throw ContentFormatException('$where: missing integer "$key"');
}

int? optInt(Map<String, dynamic> m, String key) {
  final v = m[key];
  return v is int ? v : null;
}

double reqNum(Map<String, dynamic> m, String key, String where) {
  final v = m[key];
  if (v is num) return v.toDouble();
  throw ContentFormatException('$where: missing number "$key"');
}

bool optBool(Map<String, dynamic> m, String key, {bool or = false}) {
  final v = m[key];
  return v is bool ? v : or;
}

/// Optional list of strings; missing or malformed -> empty.
List<String> strList(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is List) return v.whereType<String>().toList(growable: false);
  return const <String>[];
}

/// Optional list of objects; malformed entries are skipped.
List<Map<String, dynamic>> objList(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is List) {
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}
