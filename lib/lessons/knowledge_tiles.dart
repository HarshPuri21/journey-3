import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../knowledge/kanji/kanji.dart';
import '../knowledge/knowledge_status.dart';
import '../package_system/journey_catalog.dart';
import '../progress/progress_service.dart';
import 'japanese_text.dart';

class MissingEntity extends StatelessWidget {
  const MissingEntity(this.what, this.id, {super.key});
  final String what;
  final String id;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.error),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('Missing $what: $id', style: TextStyle(color: cs.error)),
    );
  }
}

class StatusLabel extends StatelessWidget {
  const StatusLabel(this.status, {super.key});
  final KnowledgeStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (text, color) = switch (status) {
      KnowledgeStatus.studied => ('学習', cs.primary),
      KnowledgeStatus.encountered => ('出会い', cs.tertiary),
      KnowledgeStatus.future => ('未来', cs.outline),
    };
    return Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold));
  }
}

String _readingsLine(Kanji k) {
  final parts = <String>[];
  if (k.onyomi.isNotEmpty) parts.add('音 ${k.onyomi.join('・')}');
  if (k.kunyomi.isNotEmpty) parts.add('訓 ${k.kunyomi.join('・')}');
  return parts.join('   ');
}

class KanjiTile extends StatelessWidget {
  const KanjiTile({super.key, required this.id, this.show = const ['meaning'], this.compact = false});
  final String id;
  final List<String> show;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<JourneyCatalog>().knowledge;
    final k = repo.kanji(id);
    if (k == null) return MissingEntity('kanji', id);
    final progress = context.watch<ProgressService>();
    final status = kanjiStatus(repo, progress, id);
    final t = Theme.of(context).textTheme;
    final showReadings = show.contains('readings');
    final showComponents = show.contains('components');

    if (compact) {
      return SizedBox(
        width: 104,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(k.char, style: t.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(k.meanings.join(' / '), textAlign: TextAlign.center, style: t.bodySmall),
                if (showReadings && _readingsLine(k).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_readingsLine(k), textAlign: TextAlign.center, style: t.labelSmall),
                  ),
                const SizedBox(height: 4),
                StatusLabel(status),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              Text(k.char, style: t.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
              StatusLabel(status),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.meanings.join(' / '), style: t.titleMedium),
                  if (showReadings && _readingsLine(k).isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(_readingsLine(k), style: t.bodyLarge)),
                  if (showComponents)
                    for (final c in k.components) _ComponentLine(c),
                  if (k.notes != null && showComponents)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(k.notes!, style: t.bodySmall)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentLine extends StatelessWidget {
  const _ComponentLine(this.component);
  final KanjiComponent component;

  @override
  Widget build(BuildContext context) {
    final r = context.read<JourneyCatalog>().knowledge.radical(component.radicalId);
    final role = switch (component.role) {
      ComponentRole.meaning => 'meaning clue',
      ComponentRole.sound => 'sound clue',
      ComponentRole.classifier => 'classifier',
      ComponentRole.shape => 'shape',
      ComponentRole.unknown => 'component',
    };
    final label = r == null ? component.radicalId : '${r.char} ${r.name}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('$label - $role${component.note == null ? '' : ': ${component.note}'}',
          style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class RadicalTile extends StatelessWidget {
  const RadicalTile({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<JourneyCatalog>().knowledge;
    final r = repo.radical(id);
    if (r == null) return MissingEntity('radical', id);
    final t = Theme.of(context).textTheme;
    final users = repo.kanjiUsingRadical(id).map((k) => k.char).join(' ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.char, style: t.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.name}${r.nameRomaji == null ? '' : '  (${r.nameRomaji})'}', style: t.titleMedium),
                  Text(r.meanings.join(' / '), style: t.bodyLarge),
                  if (r.note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.note!)),
                  if (users.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text('Seen in: $users', style: t.bodyMedium)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VocabTile extends StatelessWidget {
  const VocabTile({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final v = context.read<JourneyCatalog>().knowledge.vocabulary(id);
    if (v == null) return MissingEntity('vocabulary', id);
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.word, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text(v.reading, style: t.bodyLarge),
                ],
              ),
            ),
            Expanded(flex: 3, child: Text(v.meanings.join(' / '), style: t.titleMedium)),
          ],
        ),
      ),
    );
  }
}

class GrammarTile extends StatelessWidget {
  const GrammarTile({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final g = context.read<JourneyCatalog>().knowledge.grammar(id);
    if (g == null) return MissingEntity('grammar', id);
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (g.pattern != null) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(g.pattern!, style: t.titleLarge)),
            Text(g.explanation),
          ],
        ),
      ),
    );
  }
}

class SentenceTile extends StatelessWidget {
  const SentenceTile({super.key, required this.id, this.showBreakdown = true});
  final String id;
  final bool showBreakdown;

  @override
  Widget build(BuildContext context) {
    final s = context.read<JourneyCatalog>().knowledge.sentence(id);
    if (s == null) return MissingEntity('sentence', id);
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JapaneseText(s.jp, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            if (s.romaji != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.romaji!, style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic))),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.en, style: t.titleMedium)),
            if (showBreakdown && s.tokens.isNotEmpty) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  for (final tok in s.tokens)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tok.text, style: t.titleLarge),
                        if (tok.reading != null && tok.reading != tok.text) Text(tok.reading!, style: t.labelMedium),
                        if (tok.gloss != null) Text(tok.gloss!, style: t.labelSmall),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
