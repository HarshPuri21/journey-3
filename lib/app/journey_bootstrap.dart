import '../core/storage.dart';
import '../package_system/journey_catalog.dart';
import '../package_system/journey_loader.dart';
import '../package_system/pack_source.dart';
import '../progress/progress_service.dart';
import '../settings/journey_settings.dart';
import 'journey_host.dart';

/// The long-lived objects the UI reads. Built once at start-up.
class JourneyServices {
  const JourneyServices({required this.catalog, required this.settings, required this.progress});
  final JourneyCatalog catalog;
  final JourneySettings settings;
  final ProgressService progress;
}

Future<JourneyServices> bootstrapJourney(JourneyHost host) async {
  final JourneyStorage storage = host.storage ?? SharedPrefsStorage();
  final PackSource source = host.packSource ?? AssetPackSource();
  final catalog = await JourneyLoader(source).load();
  final settings = JourneySettings(storage);
  await settings.load();
  final progress = ProgressService(storage);
  await progress.load(remapLessonId: catalog.canonicalLessonId);
  return JourneyServices(catalog: catalog, settings: settings, progress: progress);
}
