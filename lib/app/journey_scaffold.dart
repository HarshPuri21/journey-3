import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/journey_settings.dart';
import '../settings/kana_reference.dart';
import '../settings/settings_sheet.dart';

/// Shared page frame: every Journey screen gets the same persistent controls
/// (furigana toggle, kana cheat-sheet, settings).
class JourneyScaffold extends StatelessWidget {
  const JourneyScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<JourneySettings>();
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Text(title),
        actions: [
          ...actions,
          IconButton(
            key: const ValueKey('furigana-toggle'),
            tooltip: settings.furiganaEnabled ? 'Furigana on' : 'Furigana off',
            icon: Icon(settings.furiganaEnabled ? Icons.subtitles : Icons.subtitles_off_outlined),
            onPressed: () => settings.setFurigana(!settings.furiganaEnabled),
          ),
          IconButton(
            key: const ValueKey('kana-button'),
            tooltip: 'Kana reference',
            icon: const Text('あ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            onPressed: () => showKanaReference(context),
          ),
          IconButton(
            key: const ValueKey('settings-button'),
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: () => showJourneySettings(context),
          ),
        ],
      ),
      body: body,
    );
  }
}
