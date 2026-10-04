import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/storage.dart';

/// Progress schema version (independent of content schema). Bump and add a
/// branch in [ProgressService.load] when the saved shape changes.
const int kProgressSchemaVersion = 1;

class TestResult {
  const TestResult(this.score, this.total, this.passed, this.at,
      {this.questionIds = const [], this.missedRefs = const []});
  final int score;
  final int total;
  final bool passed;
  final DateTime at;

  /// The questions this attempt contained (so the next attempt can vary).
  final List<String> questionIds;

  /// Knowledge ids behind the missed questions (for targeted review).
  final List<String> missedRefs;

  Map<String, dynamic> toJson() => {
        'score': score,
        'total': total,
        'passed': passed,
        'at': at.toIso8601String(),
        'questionIds': questionIds,
        'missedRefs': missedRefs,
      };

  static TestResult? fromJson(Object? v) {
    if (v is! Map) return null;
    final at = DateTime.tryParse('${v['at']}');
    if (v['score'] is! int || v['total'] is! int || at == null) return null;
    List<String> strings(Object? x) => x is List ? x.whereType<String>().toList() : <String>[];
    return TestResult(v['score'] as int, v['total'] as int, v['passed'] == true, at,
        questionIds: strings(v['questionIds']), missedRefs: strings(v['missedRefs']));
  }
}

/// Persistent learner progress, keyed ONLY by stable ids:
///   lessons `packId/lessonId`, tests `packId/testId`.
/// Ids that no longer exist in the content are kept (never dropped), so a
/// curriculum edit can never erase someone's history.
class ProgressService extends ChangeNotifier {
  ProgressService(this._storage);

  static const storageKey = 'n5journey.progress';
  final JourneyStorage _storage;

  final Map<String, DateTime> _completed = {};
  final Map<String, DateTime> _started = {};
  final Map<String, int> _cardPositions = {};
  final Map<String, List<TestResult>> _tests = {};
  bool loaded = false;

  /// [remapLessonId] resolves renamed lesson ids (`previousIds` in content).
  Future<void> load({String Function(String)? remapLessonId}) async {
    final remap = remapLessonId ?? (String s) => s;
    try {
      final raw = await _storage.read(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is Map) {
          // Future: if (j['schemaVersion'] < kProgressSchemaVersion) migrate here.
          _readDates(j['completedLessons'], _completed, remap);
          _readDates(j['startedLessons'], _started, remap);
          final pos = j['cardPositions'];
          if (pos is Map) {
            pos.forEach((k, v) {
              if (v is int) _cardPositions[remap('$k')] = v;
            });
          }
          final tests = j['testResults'];
          if (tests is Map) {
            tests.forEach((k, v) {
              if (v is List) {
                _tests['$k'] = v.map(TestResult.fromJson).whereType<TestResult>().toList();
              }
            });
          }
        }
      }
    } catch (e) {
      // A corrupt blob must never crash the app; worst case we start fresh.
      debugPrint('ProgressService.load failed, starting fresh: $e');
      _completed.clear();
      _started.clear();
      _cardPositions.clear();
      _tests.clear();
    }
    loaded = true;
    notifyListeners();
  }

  static void _readDates(Object? v, Map<String, DateTime> into, String Function(String) remap) {
    if (v is! Map) return;
    v.forEach((k, d) {
      final t = DateTime.tryParse('$d');
      if (t != null) into[remap('$k')] = t;
    });
  }

  Future<void> _save() => _storage.write(
        storageKey,
        jsonEncode({
          'schemaVersion': kProgressSchemaVersion,
          'completedLessons': _completed.map((k, v) => MapEntry(k, v.toIso8601String())),
          'startedLessons': _started.map((k, v) => MapEntry(k, v.toIso8601String())),
          'cardPositions': _cardPositions,
          'testResults': _tests.map((k, v) => MapEntry(k, v.map((r) => r.toJson()).toList())),
        }),
      );

  bool isLessonComplete(String qualifiedId) => _completed.containsKey(qualifiedId);
  bool isLessonStarted(String qualifiedId) =>
      _started.containsKey(qualifiedId) || _completed.containsKey(qualifiedId);
  int cardPosition(String qualifiedId) => _cardPositions[qualifiedId] ?? 0;
  List<TestResult> testResults(String qualifiedId) => _tests[qualifiedId] ?? const [];
  bool isTestPassed(String qualifiedId) => testResults(qualifiedId).any((r) => r.passed);

  /// Question ids of the most recent attempt (empty if never taken).
  List<String> lastAttemptQuestionIds(String qualifiedId) {
    final r = testResults(qualifiedId);
    return r.isEmpty ? const [] : r.last.questionIds;
  }

  /// How often each knowledge id has been missed across all attempts.
  Map<String, int> missedRefCounts() {
    final out = <String, int>{};
    for (final results in _tests.values) {
      for (final r in results) {
        for (final id in r.missedRefs) {
          out[id] = (out[id] ?? 0) + 1;
        }
      }
    }
    return out;
  }
  Set<String> get completedLessonIds => _completed.keys.toSet();

  Future<void> markLessonStarted(String id) async {
    if (_started.containsKey(id)) return;
    _started[id] = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> markLessonComplete(String id) async {
    _completed.putIfAbsent(id, DateTime.now);
    notifyListeners();
    await _save();
  }

  /// Remembers where the learner was; deliberately does not notify listeners.
  Future<void> saveCardPosition(String id, int index) async {
    if (_cardPositions[id] == index) return;
    _cardPositions[id] = index;
    await _save();
  }

  Future<void> recordTestResult(String id, TestResult result) async {
    (_tests[id] ??= []).add(result);
    notifyListeners();
    await _save();
  }

  Future<void> resetAll() async {
    _completed.clear();
    _started.clear();
    _cardPositions.clear();
    _tests.clear();
    notifyListeners();
    await _storage.remove(storageKey);
  }
}
