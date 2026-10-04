import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/journey_host.dart';
import '../app/journey_scaffold.dart';
import '../lessons/japanese_text.dart';
import '../navigation/journey_routes.dart';
import '../package_system/journey_catalog.dart';
import '../prefectures/prefecture_screen.dart';
import '../prefectures/unlock_evaluator.dart';
import '../progress/progress_service.dart';
import '../settings/journey_settings.dart';
import 'illustrated_journey_map.dart';
import 'node_map.dart';

/// Country level: the illustrated route, in curriculum order.
class JapanMapScreen extends StatefulWidget {
  const JapanMapScreen({super.key});

  @override
  State<JapanMapScreen> createState() => _JapanMapScreenState();
}

class _JapanMapScreenState extends State<JapanMapScreen> {
  String? _selectedId;

  Future<void> _showStops(List<MapNode> nodes) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                child: Row(children: [
                  Expanded(child: Text('Journey stops', style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(tooltip: 'Close stops', onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ]),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: nodes.length,
                  itemBuilder: (context, i) {
                    final n = nodes[i];
                    return ListTile(
                      key: ValueKey('route-stop-${n.id}'),
                      selected: n.id == _selectedId,
                      leading: CircleAvatar(child: Text('${n.number}')),
                      title: Text('${n.label} · ${n.sublabel}'),
                      subtitle: Text(nodeStatusLabel(n.state)),
                      trailing: Icon(nodeStatusIcon(n.state)),
                      onTap: () => Navigator.pop(context, n.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (id != null && mounted) setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<JourneyCatalog>();
    final progress = context.watch<ProgressService>();
    final settings = context.watch<JourneySettings>();
    final host = context.read<JourneyHost>();
    final unlocks = UnlockEvaluator(catalog, progress);
    final nodes = [
      for (final p in catalog.prefectures)
        MapNode(
          id: p.id,
          number: p.route.number,
          label: p.route.name,
          sublabel: p.route.nameEn,
          position: p.route.map,
          state: !p.installed ? NodeState.comingLater
              : unlocks.isPrefectureComplete(p.id) ? NodeState.completed
              : unlocks.isPrefectureUnlocked(p.id) ? NodeState.available : NodeState.locked,
        ),
    ];
    if (nodes.isNotEmpty && !nodes.any((n) => n.id == _selectedId)) {
      _selectedId = nodes.firstWhere((n) => n.state == NodeState.available, orElse: () => nodes.first).id;
    }

    return JourneyScaffold(
      title: catalog.index.title,
      leading: host.embedded
          ? IconButton(
              icon: const Icon(Icons.close), tooltip: 'Close Journey',
              onPressed: () {
                host.onExit?.call();
                Navigator.of(context, rootNavigator: true).pop();
              },
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!settings.kanaNoticeDismissed) _KanaNotice(onDismiss: settings.dismissKanaNotice),
            Expanded(
              child: nodes.isEmpty ? const Center(child: Text('No journey stops installed.'))
                  : LayoutBuilder(builder: (context, constraints) {
                      final selected = nodes.firstWhere((n) => n.id == _selectedId);
                      final map = IllustratedJourneyMap(
                        nodes: nodes, selectedId: selected.id,
                        onSelect: (id) => setState(() => _selectedId = id),
                      );
                      final panel = _StopPanel(
                        entry: catalog.prefecture(selected.id)!,
                        state: selected.state,
                        catalog: catalog,
                        onShowStops: () => _showStops(nodes),
                        onEnter: () {
                          // Re-check current rules at entry; selecting a pin never bypasses them.
                          final current = UnlockEvaluator(catalog, context.read<ProgressService>());
                          if (current.isPrefectureUnlocked(selected.id) || current.isPrefectureComplete(selected.id)) {
                            zoomInTo<void>(context, PrefectureScreen(prefectureId: selected.id));
                          }
                        },
                      );
                      if (constraints.maxWidth > constraints.maxHeight && constraints.maxWidth >= 600) {
                        return Row(children: [
                          Expanded(child: map),
                          SizedBox(width: (constraints.maxWidth * 0.38).clamp(250.0, 340.0).toDouble(), child: panel),
                        ]);
                      }
                      return Column(children: [
                        Expanded(child: map),
                        SizedBox(height: (constraints.maxHeight * 0.36).clamp(130.0, 250.0).toDouble(), child: panel),
                      ]);
                    }),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopPanel extends StatelessWidget {
  const _StopPanel({required this.entry, required this.state, required this.catalog,
    required this.onShowStops, required this.onEnter});
  final PrefectureEntry entry;
  final NodeState state;
  final JourneyCatalog catalog;
  final VoidCallback onShowStops;
  final VoidCallback onEnter;

  String get _description {
    if (state == NodeState.comingLater) return 'This prefecture is coming later.';
    if (state == NodeState.completed) return 'Journey completed. You can revisit your lessons.';
    if (state == NodeState.available) {
      return '${entry.pack!.chapters.length} locations · Reading journey · 30-question test';
    }
    final requirements = entry.pack!.manifest.unlock.map((r) {
      final parts = r.ref.split('/');
      final name = catalog.prefecture(parts.first)?.route.nameEn ?? parts.first;
      return switch (r.type) {
        'prefectureComplete' => 'Complete $name to unlock this stop.',
        'testPassed' => 'Pass the $name test to unlock this stop.',
        'lessonComplete' => 'Finish ${catalog.lessonByQualifiedId(r.ref)?.title ?? r.ref} to unlock this stop.',
        'chapterComplete' => 'Finish the earlier location in $name to unlock this stop.',
        _ => 'An earlier journey requirement is still incomplete.',
      };
    }).join(' ');
    return requirements.isEmpty ? 'This stop is locked.' : requirements;
  }

  @override
  Widget build(BuildContext context) {
    final canEnter = state == NodeState.available || state == NodeState.completed;
    final route = entry.route;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(children: [
        Expanded(child: SingleChildScrollView(
        key: const ValueKey('selected-stop-panel'),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(child: Text('${route.number}')),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              JapaneseText(route.nameReading == null ? route.name : '{${route.name}|${route.nameReading}}',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(route.nameEn, style: Theme.of(context).textTheme.titleSmall),
            ])),
            Icon(nodeStatusIcon(state)),
          ]),
          const SizedBox(height: 8),
          Text(nodeStatusLabel(state), key: const ValueKey('selected-stop-status'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(_description, key: const ValueKey('selected-stop-description')),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: ValueKey('enter-${entry.id}'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: canEnter ? onEnter : null,
            icon: Icon(canEnter ? Icons.arrow_forward : nodeStatusIcon(state)),
            label: Text(canEnter ? (state == NodeState.completed ? 'Review ${route.nameEn}' : 'Explore ${route.nameEn}')
                : nodeStatusLabel(state)),
          ),
        ]),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
            key: const ValueKey('journey-stops'), onPressed: onShowStops,
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.format_list_numbered), label: const Text('All journey stops'),
          )),
        ),
      ]),
    );
  }
}

class _KanaNotice extends StatelessWidget {
  const _KanaNotice({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('kana-notice'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(children: [
          const Expanded(child: Text('Know hiragana and katakana first.')),
          IconButton(
            tooltip: 'About kana preparation', icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(context: context, builder: (context) => AlertDialog(
              title: const Text('Before your journey'),
              content: const Text('Journey assumes you know hiragana and katakana. Please do the kana lessons first. '
                  'The あ button always opens a quick chart.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
            )),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Got it')),
        ]),
      ),
    );
  }
}
