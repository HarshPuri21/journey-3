import 'package:flutter/material.dart';
import 'package:n5_kanji_journey/app/journey_bootstrap.dart';
import 'package:n5_kanji_journey/app/journey_shell.dart';
import 'package:n5_kanji_journey/app/journey_theme.dart';
import 'package:n5_kanji_journey/core/storage.dart';
import 'package:n5_kanji_journey/package_system/journey_loader.dart';
import 'package:n5_kanji_journey/package_system/pack_source.dart';
import 'package:n5_kanji_journey/progress/progress_service.dart';
import 'package:n5_kanji_journey/settings/journey_settings.dart';

import 'disk_pack_source.dart';

/// Builds real services over the shipped content (or any [PackSource]) with
/// in-memory storage. Call inside `tester.runAsync` in widget tests.
Future<JourneyServices> loadTestServices({PackSource? source, MemoryStorage? storage}) async {
  final store = storage ?? MemoryStorage();
  final catalog = await JourneyLoader(source ?? DiskPackSource()).load();
  final settings = JourneySettings(store);
  await settings.load();
  final progress = ProgressService(store);
  await progress.load(remapLessonId: catalog.canonicalLessonId);
  return JourneyServices(catalog: catalog, settings: settings, progress: progress);
}

Widget harness(JourneyServices services, Widget home) => JourneyProviders(
      services: services,
      child: MaterialApp(theme: buildJourneyTheme(), home: home),
    );
