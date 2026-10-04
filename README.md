# N5 Kanji Journey

This release includes Packages 1–5: ten prefectures from Hokkaido through Gunma,
42 complete locations, ten readings and 600 questions. The country screen uses
the bundled illustrated Japan map with zoom, pan, fit/focus controls and an
ordered stop list. See `IMPLEMENTATION_REPORT.md` for validation results and
the runtime/build checks that still require Flutter or GitHub CI.

A geographical Japanese-learning journey: the learner travels from Hokkaido southward, one prefecture
(content pack) at a time, learning kanji, radicals, vocabulary, grammar and sentences through card-based
lessons. This repository is a **standalone Flutter/Android app** and the **foundation engine** - it does not
depend on, import from, or read the data of any other app.

> The engine is the railway. Prefectures are trains. Lessons are carriages. Knowledge entities are
> reusable infrastructure.

## Development model: GitHub Actions only

Nothing here needs Android Studio, an Android SDK, a Flutter SDK or an emulator locally. Push, then read
the Actions run.

| Job | What it does | Fails when |
|---|---|---|
| `validate-content` | Python validator self-tests, then validates every pack | any dangling id, duplicate id, missing file/asset, schema error, bad dependency, unlock cycle, stale pubspec asset list |
| `test` (needs validate) | `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test` | resolve error, analyzer error **or warning**, any failing test |
| `build-apk` (needs test) | generates `android/`, `flutter build apk --release`, uploads the APK artifact | build error |

No step uses `continue-on-error`. The APK is only built when content, analysis and tests are green.
Download it from the run's **Artifacts** (`n5-kanji-journey-apk`).

Optional local commands (never required): `python3 tool/validate_content.py` (instant content check),
`python3 -m unittest discover -s tool/tests`.

## Layout

```
content/                      DATA ONLY - curriculum lives here, no Dart
  journey_index.json          the route: prefecture order, numbers, names, map positions
  packs/<packId>/             one folder per prefecture (a "train")
    manifest.json             metadata, dependencies, unlock + completion rules, chapter list, tests
    chapters/*.json           a location (e.g. Sapporo) and its lessons
    lessons/*.json            a lesson = ordered cards = blocks
    knowledge/*.json          kanji, radicals, vocabulary, grammar, sentences, stories
    tests/questions.json      the question bank
    assets/                   images etc.
lib/
  n5_journey.dart             the ONLY public API (JourneyApp, JourneyShell, openN5Journey, JourneyHost)
  app/ core/ navigation/      shell, host, theme, ids, storage, markup, json helpers
  package_system/             PackSource, loader, catalog, schema versioning + migrations
  knowledge/ stories/ tests/  reusable entities + KnowledgeRepository (the data boundary)
  lessons/                    lesson renderer, block renderers, synced card strip
  map/ prefectures/ chapters/ country map, prefecture mini-map, chapter screens (+ unlock evaluator)
  tests/                      question model, quota-balanced TestSession, test screen
  progress/ settings/         persistent progress, furigana + kana reference
tool/                         validate_content.py (CI gate), bootstrap_android.sh
test/                         unit + widget tests (run against the real shipped content)
```

## How the engine stays generic

* **No per-prefecture code.** Adding Aomori = adding `content/packs/aomori/`. The test
  `second_pack_test.dart` proves a second pack installs, unlocks, shares knowledge with Hokkaido and
  renders in the same `LessonScreen` without touching the engine.
* **Stable ids everywhere** - `kanji_海`, `radical_sanzui`, `vocab_北海道`, `sent_...`, lessons as
  `packId/lessonId`. Progress is keyed only by these. Display numbers are never identifiers.
* **Kanji are shared entities.** Lessons reference ids. "Which lessons teach 北", "which kanji use 氵",
  "which words contain 道" are *derived indexes* built at load time.
* **Incomplete is valid.** Route entries without an installed pack are "coming later". A pack that fails
  to load (bad schema, missing dependency) is skipped with a diagnostic (Settings -> Content
  diagnostics); a broken knowledge/lesson file drops only that file.
* **Unlocking is data.** `manifest.unlock`, `manifest.completion` and `chapter.unlock` use rules
  (`prefectureComplete`, `chapterComplete`, `lessonComplete`, `testPassed`). Unknown rule types stay locked.
* **Furigana is one global setting.** Content writes `{北海道|ほっかいどう}`; `JapaneseText` decides.
* **New lesson content = new block type.** Add a case in `block_renderers.dart` and a spec in the
  validator. Unknown block types render a visible placeholder.

## Curriculum schema versioning (explicit concern)

The curriculum will change a lot, so change is designed for:

1. Every document carries `schemaVersion`. The engine reads `kMinReadableSchemaVersion..kCurrentSchemaVersion`
   (`lib/package_system/schema/schema_version.dart`).
2. Older documents are upgraded **in memory before parsing** by `SchemaMigrator`
   (registered `N -> N+1` migrations, run in sequence). Newer-than-app documents are refused with a clear
   diagnostic, never half-parsed.
3. Packs declare `contentVersion` (their own revision) and `engineSchemaMin`.
4. Renaming an entity? Keep the old id in `previousIds`; the validator rejects collisions and the app
   remaps saved progress, so learner history survives curriculum edits.
5. Progress has its own schema version, and ids missing from the content are preserved, never deleted.
6. The validator reads the same Dart constants, so CI fails if validator and engine ever disagree.

**To change the format:** bump `kCurrentSchemaVersion`, add the migration, update the specs in
`tool/validate_content.py`, add a test. See `docs/CONTENT_SCHEMA.md`.

## Content validator (`tool/validate_content.py`)

Runs before Flutter is installed. Checks: JSON + shape of every document type (typos in field names are
warnings), `schemaVersion` bounds, id format/prefix, duplicate ids (file, pack and cross-pack), references
resolving within the pack **or its declared dependencies**, referenced files and assets existing, orphan
files, dependency cycles/missing deps, route/pack mismatches, unlock-rule targets and cycles,
furigana/bold markup, question answers, test pool sizes, and that `pubspec.yaml`'s asset list matches
`content/` (Flutter assets are not recursive - run `python3 tool/validate_content.py --sync-assets`
after adding folders). Annotations appear inline on the GitHub run. `--strict` makes warnings fatal.

## Building the next package

See **docs/PACKAGE_TEMPLATE.md** - `content/packs/hokkaido/` is the blueprint.

## Adding a prefecture

1. Add its entry to `content/journey_index.json` (if not there) and create `content/packs/<id>/`.
2. Copy the Hokkaido structure; set `dependencies` for any pack whose kanji/radicals you reuse.
3. `python3 tool/validate_content.py --sync-assets` (or let CI tell you what's wrong), commit, push.

## Integrating with the main app later

```dart
import 'package:n5_kanji_journey/n5_journey.dart';
openN5Journey(context, host: JourneyHost(storage: ..., packSource: ..., onExit: ...));
```
Journey runs its own nested `Navigator` and providers. The main app never learns about prefectures or
progress. A `MainAppKnowledgeAdapter` would implement `KnowledgeRepository`; dependencies only point from
the main app **to** Journey.

## Known limitations / next steps (phase 1)

* **APK signing:** CI signs with the fixed personal-use key in `tool/debug.keystore`, so a new build installs
  over the old one and keeps progress. For a Play Store release, switch to a private upload key in GitHub secrets.
* The country map uses decorative illustrated artwork with approximate visual anchors.
  Prefecture location mini-maps remain schematic; later curriculum packages are not included.
* Packs load eagerly (async, per pack). Lazy per-chapter loading is the planned upgrade for scale.
* Targeted review: missed knowledge ids are recorded with every test result, but there is no review screen yet.
* Forward links to kanji in packages that are not installed yet ("you'll meet this in Aomori") need a planned-links field.
* Bundled CJK font not included; relies on the device's system font.
* The Dart code was written without a compiler available; the first CI run may need a small fix-up round.
