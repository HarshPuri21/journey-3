import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../map/japan_map_screen.dart';
import '../package_system/journey_catalog.dart';
import '../progress/progress_service.dart';
import '../settings/journey_settings.dart';
import 'journey_bootstrap.dart';
import 'journey_host.dart';
import 'journey_theme.dart';

/// Makes the Journey services available to every widget below it.
class JourneyProviders extends StatelessWidget {
  const JourneyProviders({
    super.key,
    required this.services,
    required this.child,
    this.host = const JourneyHost(),
  });

  final JourneyServices services;
  final JourneyHost host;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<JourneyHost>.value(value: host),
        Provider<JourneyCatalog>.value(value: services.catalog),
        ChangeNotifierProvider<JourneySettings>.value(value: services.settings),
        ChangeNotifierProvider<ProgressService>.value(value: services.progress),
      ],
      child: child,
    );
  }
}

/// Journey as an embeddable unit: loads content, then runs its own nested
/// Navigator (so the host app's navigation is untouched).
class JourneyShell extends StatefulWidget {
  const JourneyShell({super.key, this.host = const JourneyHost()});
  final JourneyHost host;

  @override
  State<JourneyShell> createState() => _JourneyShellState();
}

class _JourneyShellState extends State<JourneyShell> {
  late final Future<JourneyServices> _services = bootstrapJourney(widget.host);
  final GlobalKey<NavigatorState> _nav = GlobalKey<NavigatorState>();

  void _handleBack(bool didPop) {
    if (didPop) return;
    final nested = _nav.currentState;
    if (nested != null && nested.canPop()) {
      nested.pop();
    } else if (widget.host.embedded) {
      widget.host.onExit?.call();
      Navigator.of(context).pop();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JourneyServices>(
      future: _services,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Journey could not start.\n\n${snap.error}', textAlign: TextAlign.center),
              ),
            ),
          );
        }
        final services = snap.data;
        if (services == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return JourneyProviders(
          services: services,
          host: widget.host,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
            child: Navigator(
              key: _nav,
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const JapanMapScreen()),
            ),
          ),
        );
      },
    );
  }
}

/// The standalone application.
class JourneyApp extends StatelessWidget {
  const JourneyApp({super.key, this.host = const JourneyHost()});
  final JourneyHost host;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N5 Kanji Journey',
      debugShowCheckedModeBanner: false,
      theme: buildJourneyTheme(),
      home: JourneyShell(host: host),
    );
  }
}
