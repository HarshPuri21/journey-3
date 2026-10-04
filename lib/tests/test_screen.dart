import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/journey_scaffold.dart';
import '../package_system/journey_catalog.dart';
import '../progress/progress_service.dart';
import 'question.dart';
import 'test_session.dart';

/// Runs one test from a pack: draws the questions (quota-balanced, varying from
/// the previous attempt), gives instant feedback, records the result and the
/// knowledge ids that were missed.
class TestScreen extends StatefulWidget {
  const TestScreen({super.key, required this.packId, required this.testId});
  final String packId;
  final String testId;

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  TestSession? _session;
  int _index = 0;
  String? _picked;
  final Map<String, String> _answers = {};
  TestResult? _result;

  String get _key => '${widget.packId}/${widget.testId}';

  @override
  void initState() {
    super.initState();
    _begin();
  }

  void _begin() {
    final catalog = context.read<JourneyCatalog>();
    final progress = context.read<ProgressService>();
    final pack = catalog.pack(widget.packId);
    TestDefinition? def;
    for (final t in pack?.manifest.tests ?? const <TestDefinition>[]) {
      if (t.id == widget.testId) def = t;
    }
    _index = 0;
    _picked = null;
    _result = null;
    _answers.clear();
    if (pack == null || def == null) {
      _session = null;
      return;
    }
    _session = TestSession.start(def, pack.questions, avoid: progress.lastAttemptQuestionIds(_key).toSet());
  }

  Future<void> _next() async {
    final session = _session!;
    final progress = context.read<ProgressService>();
    if (_index + 1 < session.questions.length) {
      setState(() {
        _index++;
        _picked = null;
      });
      return;
    }
    final score = session.score(_answers);
    final result = TestResult(
      score,
      session.questions.length,
      session.passed(score),
      DateTime.now(),
      questionIds: session.questions.map((q) => q.id).toList(),
      missedRefs: session.missedRefs(_answers).toList(),
    );
    await progress.recordTestResult(_key, result);
    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null || session.questions.isEmpty) {
      return const JourneyScaffold(title: 'Test', body: Center(child: Text('This test is not available.')));
    }
    final result = _result;
    if (result != null) return _buildResult(session, result);

    final t = Theme.of(context).textTheme;
    final q = session.questions[_index];
    final total = session.questions.length;
    final last = _index + 1 == total;
    return JourneyScaffold(
      title: session.definition.title,
      body: Column(
        children: [
          LinearProgressIndicator(value: (_index + (_picked == null ? 0 : 1)) / total, minHeight: 3),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Question ${_index + 1} of $total', style: t.labelLarge),
                const SizedBox(height: 8),
                Text(q.prompt, key: const ValueKey('question-prompt'), style: t.headlineSmall),
                const SizedBox(height: 16),
                for (final c in q.choices) _choice(q, c),
                if (_picked != null && q.explanation != null)
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text(q.explanation!)),
              ],
            ),
          ),
          if (_picked != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('next-question'),
                    onPressed: _next,
                    child: Text(last ? 'Finish' : 'Next'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _choice(Question q, Choice c) {
    final cs = Theme.of(context).colorScheme;
    final answered = _picked != null;
    Color? bg;
    if (answered && c.id == q.answerId) {
      bg = cs.tertiaryContainer;
    } else if (answered && c.id == _picked) {
      bg = cs.errorContainer;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: OutlinedButton(
        key: ValueKey('choice-${c.id}'),
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: cs.onSurface,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
        ),
        onPressed: answered
            ? null
            : () => setState(() {
                  _picked = c.id;
                  _answers[q.id] = c.id;
                }),
        child: Text(c.text, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }

  Widget _buildResult(TestSession session, TestResult result) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final missed = session.missed(_answers);
    return JourneyScaffold(
      title: session.definition.title,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(result.passed ? Icons.emoji_events_outlined : Icons.refresh,
              size: 56, color: result.passed ? cs.tertiary : cs.error),
          const SizedBox(height: 8),
          Text('${result.score} / ${result.total}',
              key: const ValueKey('test-score'), textAlign: TextAlign.center, style: t.displayMedium),
          Text(
            result.passed ? 'Passed!' : 'Not quite yet - review and try again.',
            textAlign: TextAlign.center,
            style: t.titleLarge,
          ),
          const SizedBox(height: 16),
          if (missed.isNotEmpty) Text('To review', style: t.titleMedium),
          for (final q in missed)
            ListTile(
              dense: true,
              title: Text(q.prompt),
              subtitle: Text('Answer: ${q.choices.firstWhere((c) => c.id == q.answerId).text}'),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('retake-test'),
            onPressed: () => setState(_begin),
            child: const Text('Take it again (new questions)'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
  }
}
