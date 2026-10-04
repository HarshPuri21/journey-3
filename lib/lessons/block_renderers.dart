import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/journey_settings.dart';
import 'japanese_text.dart';
import 'knowledge_tiles.dart';
import 'lesson_models.dart';

/// Block type -> widget. To add a new kind of lesson content, add a case here
/// (and a spec in tool/validate_content.py); lesson data needs no other change.
/// Unknown types render a visible placeholder instead of failing.
Widget buildContentBlock(BuildContext context, ContentBlock b) {
  final t = Theme.of(context).textTheme;
  switch (b.type) {
    case 'heading':
      final level = b.integer('level') ?? 2;
      final style = level <= 1 ? t.headlineMedium : (level == 2 ? t.titleLarge : t.titleMedium);
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: JapaneseText(b.str('text') ?? '', style: style?.copyWith(fontWeight: FontWeight.bold)),
      );
    case 'text':
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: JapaneseText(b.str('text') ?? '', style: t.bodyLarge?.copyWith(height: 1.55)),
      );
    case 'display':
      return _DisplayBlock(b);
    case 'callout':
      return _CalloutBlock(b);
    case 'bullets':
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in b.strings('items'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: JapaneseText(item, style: t.bodyLarge)),
                  ],
                ),
              ),
          ],
        ),
      );
    case 'divider':
      return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider());
    case 'kanjiRef':
      return KanjiTile(id: b.str('id') ?? '', show: _show(b));
    case 'kanjiRow':
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (final id in b.strings('ids')) KanjiTile(id: id, show: _show(b), compact: true)],
        ),
      );
    case 'radicalRef':
      return RadicalTile(id: b.str('id') ?? '');
    case 'vocabRef':
      return VocabTile(id: b.str('id') ?? '');
    case 'sentenceRef':
      return SentenceTile(id: b.str('id') ?? '', showBreakdown: b.flag('showBreakdown', or: true));
    case 'grammarRef':
      return GrammarTile(id: b.str('id') ?? '');
    case 'readingLine':
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JapaneseText(b.str('jp') ?? '', style: t.headlineSmall?.copyWith(height: 1.3)),
            if (b.str('en') != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(b.str('en')!, style: t.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.outline)),
              ),
          ],
        ),
      );
    default:
      return _UnsupportedBlock(b.type);
  }
}

List<String> _show(ContentBlock b) {
  final s = b.strings('show');
  return s.isEmpty ? const ['meaning'] : s;
}

class _DisplayBlock extends StatelessWidget {
  const _DisplayBlock(this.block);
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final furigana = context.watch<JourneySettings>().furiganaEnabled;
    final reading = block.str('reading');
    final romaji = block.str('romaji');
    final gloss = block.str('gloss');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          JapaneseText(block.str('jp') ?? '',
              textAlign: TextAlign.center, style: t.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (reading != null && furigana) Text(reading, style: t.titleLarge),
          if (romaji != null) Text(romaji, style: t.titleMedium),
          if (gloss != null) Text(gloss, style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}

class _CalloutBlock extends StatelessWidget {
  const _CalloutBlock(this.block);
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final tone = block.str('tone') ?? 'info';
    final (bg, fg) = switch (tone) {
      'tip' => (cs.tertiaryContainer, cs.onTertiaryContainer),
      'warning' => (cs.errorContainer, cs.onErrorContainer),
      'quote' => (cs.surfaceContainerHighest, cs.onSurface),
      _ => (cs.secondaryContainer, cs.onSecondaryContainer),
    };
    final title = block.str('title');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(title, style: t.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.bold)),
            ),
          JapaneseText(
            block.str('text') ?? '',
            style: t.bodyLarge?.copyWith(color: fg, fontStyle: tone == 'quote' ? FontStyle.italic : null),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedBlock extends StatelessWidget {
  const _UnsupportedBlock(this.type);
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('Unsupported content block "$type" - update the app to see this.'),
    );
  }
}
