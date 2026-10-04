import '../core/storage.dart';
import '../package_system/pack_source.dart';

/// Everything the embedding application may customise. All fields optional:
/// `const JourneyHost()` is a complete standalone configuration.
///
/// This is the *only* integration surface. The main app never learns about
/// prefectures, lessons or progress - it passes a host and calls
/// `openN5Journey`.
class JourneyHost {
  const JourneyHost({this.storage, this.packSource, this.onExit, this.embedded = false});

  /// Where progress/settings are persisted. Defaults to SharedPreferences.
  final JourneyStorage? storage;

  /// Where content packs come from. Defaults to bundled assets.
  final PackSource? packSource;

  /// Called when the learner leaves Journey (embedded mode).
  final void Function()? onExit;

  /// True when Journey runs inside another app (shows a close button).
  final bool embedded;

  JourneyHost copyWith({bool? embedded}) => JourneyHost(
        storage: storage,
        packSource: packSource,
        onExit: onExit,
        embedded: embedded ?? this.embedded,
      );
}
