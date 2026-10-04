import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../package_system/journey_catalog.dart';
import '../progress/progress_service.dart';
import 'journey_settings.dart';
import 'kana_reference.dart';

Future<void> showJourneySettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<JourneySettings>();
    final catalog = context.read<JourneyCatalog>();
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          SwitchListTile(
            title: const Text('Show furigana'),
            subtitle: const Text('Reading aids above kanji. Try turning them off once you feel ready.'),
            value: settings.furiganaEnabled,
            onChanged: settings.setFurigana,
          ),
          ListTile(
            leading: const Text('あ', style: TextStyle(fontSize: 22)),
            title: const Text('Kana reference'),
            onTap: () {
              Navigator.of(context).pop();
              showKanaReference(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset progress'),
            onTap: () async {
              final progress = context.read<ProgressService>();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset all progress?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset')),
                  ],
                ),
              );
              if (ok == true) await progress.resetAll();
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.rule),
            title: Text('Content diagnostics (${catalog.diagnostics.length})'),
            subtitle: Text('${catalog.packs.length} pack(s) installed'),
            children: [
              if (catalog.diagnostics.isEmpty)
                const ListTile(dense: true, title: Text('No problems found.'))
              else
                for (final d in catalog.diagnostics) ListTile(dense: true, title: Text(d.toString())),
            ],
          ),
        ],
      ),
    );
  }
}
