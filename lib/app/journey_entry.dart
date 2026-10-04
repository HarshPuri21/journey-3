import 'package:flutter/material.dart';

import 'journey_host.dart';
import 'journey_shell.dart';
import 'journey_theme.dart';

/// The single entry point the main app calls:
///
///     openN5Journey(context);
///
/// Journey pushes one route containing its own Navigator, providers and
/// state. Nothing about prefectures, lessons or progress leaks out.
Future<void> openN5Journey(BuildContext context, {JourneyHost host = const JourneyHost()}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Theme(
        data: buildJourneyTheme(),
        child: JourneyShell(host: host.copyWith(embedded: true)),
      ),
    ),
  );
}
