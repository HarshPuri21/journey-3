# Packages 01–05 and illustrated Japan map — implementation report

Prepared 4 October 2026 from the supplied `n5_kanji_journey_fixed_v3(1).zip`,
five completed curriculum ZIPs and `First_5_Packages_Map_Implementation_Handoff.zip`.

**Status: source changes complete; content validation passed. Flutter analysis,
Flutter runtime tests, APK compilation and device installation have not been run
because this workspace has no Flutter/Dart SDK or connected repository CI.**
No APK or Flutter-rendered screenshots are included. The source must pass the
supplied GitHub workflow before distributing an APK.

## Installed inventory

| Journey | Prefecture | Locations | Location cards | Reading cards | Bank questions |
|---:|---|---:|---:|---:|---:|
| 1 | Hokkaido | 9 | 98 | 22 | 60 |
| 2 | Aomori | 3 | 36 | 12 | 60 |
| 3 | Iwate | 3 | 37 | 12 | 60 |
| 4 | Miyagi | 4 | 48 | 12 | 60 |
| 5 | Akita | 3 | 36 | 12 | 60 |
| 6 | Yamagata | 3 | 36 | 12 | 60 |
| 7 | Fukushima | 4 | 48 | 12 | 60 |
| 8 | Ibaraki | 5 | 60 | 12 | 60 |
| 9 | Tochigi | 4 | 48 | 12 | 60 |
| 10 | Gunma | 4 | 48 | 12 | 60 |
| **Total** | **10 packs** | **42** | **495** | **130** | **600** |

There are ten cumulative reading modules. Hokkaido retains its 22 reading cards;
Hanamaki retains its 13 location cards. Hokkaido contentVersion is 3. All source
content files in the installed packs are byte-for-byte identical to the supplied
completed packages, including assistance, translations, core/encounter roles,
canonical ownership, prior IDs, modern place labels and reading-question passages.
No later content was present in the supplied base, and none was added.

The supplied reversible installers ran in package order, each with `--check`
before installation. Package 2 installed completed Hokkaido together with Aomori
and Iwate. Packages 3–5 extended the integrated state through Gunma. Installer
backups remain outside the app folder and are excluded from the deliverable.
Schema version remains 1. Package 5 added the three route entries in order;
only the existing route `map` coordinates were recalibrated for the artwork.

## Country map

- `assets/maps/japan_journey_map.png` contains the exact original 941 × 1672 PNG.
  SHA-256: `600f4399550da1e2e01cff2d36b0543f5f912793e18faeb97562b3eb61d79376`.
- The PNG is explicitly registered outside the generated content asset section;
  asset synchronization was run afterwards and preserved that registration.
- `lib/map/illustrated_journey_map.dart` projects normalized anchors into the
  centered, contained image rectangle. Background and pins share one image-sized
  canvas inside a single `InteractiveViewer`, so zoom and pan transform both.
  There is no cover cropping or stretching. Resize fits the map again.
- Fit, zoom in/out and focus-selected controls support 1×–6× zoom. Compact
  pins shrink according to the nearest anchor spacing at fit scale; zoom enlarges
  the actual targets. Full-size controls and an ordered stop sheet provide a
  reliable selection path through the northern cluster.
- The selected detail panel includes Japanese/English names, journey number,
  a status icon and text, prerequisite explanation, and an entry/review button.
  The stop-list button stays outside the scrolling detail area. Landscape places
  the panel alongside the map; portrait places it below.
- States come from the real catalog, ProgressService and UnlockEvaluator.
  Selecting a pin only selects its detail. Entry is disabled for locked/absent
  packs, and rules are checked again when entering an available/completed pack.
  Fresh progress therefore makes only Hokkaido available; nine installed stops
  are locked. Existing chapter, reading and test rules determine subsequent gates.
- Pin keys remain `node-<prefectureId>`. Prefecture mini-maps and chapter
  navigation continue to use the unchanged `NodeMapView`.
- The ordered sheet follows curriculum order, including Miyagi before Akita.
  A connecting line was omitted to keep the tightly clustered artwork clear.
- Kana preparation notice, persistent dismissal, global furigana, kana/settings
  buttons, embedded exit and existing nested navigation remain available. The
  notice is compact, with its full explanation in an information dialog.

### Final visual anchors

These are approximate positions on decorative artwork, not geographic
centroids or selectable administrative boundaries. Positions were visually
checked on the original PNG; several supplied seeds were moved into region
interiors. Coordinates belong to the image rectangle, excluding letterboxing.

| Prefecture | x | y |
|---|---:|---:|
| Hokkaido | 0.780 | 0.195 |
| Aomori | 0.692 | 0.288 |
| Iwate | 0.815 | 0.350 |
| Miyagi | 0.805 | 0.409 |
| Akita | 0.664 | 0.385 |
| Yamagata | 0.654 | 0.450 |
| Fukushima | 0.774 | 0.471 |
| Ibaraki | 0.831 | 0.566 |
| Tochigi | 0.745 | 0.529 |
| Gunma | 0.680 | 0.506 |

## Progress and compatibility

The original progress, storage, settings, unlock evaluator, lesson renderer,
question engine, schema loader and mini-map source files were verified unchanged
by byte comparison against the uploaded base. Existing lesson IDs and progress
namespaces are retained. Tests continue to draw 30 questions, five per category;
21 passes and 20 fails. No seeded/completed progress ships with the app.

The fixed `tool/debug.keystore`, bootstrap script, organization/application ID
and app version are preserved. The CI command still uses
`bash tool/bootstrap_android.sh`, retaining the earlier permission fix. The
earlier Dart export-order fix and quota-aware retake regression test are present.
CI content validation now uses `--strict` so future warnings also fail the gate.

Obsolete fixtures were narrowly updated by the supplied installers. The original
country navigation widget test now verifies installed-but-locked Aomori and
selects/enters Hokkaido before continuing through chapter and lesson navigation.
A deliberately absent-content fixture separately tests coming-later behavior.

## Verification actually run

Python: **3.12.14**.

| Check | Actual result |
|---|---|
| Each Package 2–5 prerequisite check and sequential installer | Passed |
| `python3 tool/validate_content.py --sync-assets --strict` on final app | Passed; 0 errors, 0 warnings |
| `python3 -m unittest discover -s tool/tests -v` | All 29 passed |
| Package 2 `audit_package.py --root <app>` | Passed; source content preserved, 0 errors/warnings |
| Package 3 source audit on final app | Passed |
| Package 4 source audit on final app | Passed |
| Package 5 source audit on final app | Passed |
| Independent manifest/lesson/reading/question inventory | Exact totals in the table above |
| Completed Hokkaido and Package 2–5 installed file comparisons | All supplied content bytes preserved |
| Original PNG bytes, dimensions and asset registration | Passed, including after asset synchronization |
| Existing engine/settings/progress/signing/bootstrap byte comparisons | Passed |
| Workflow YAML parse and Bash bootstrap syntax | Passed |
| Final source ZIP integrity | Checked during packaging |
| `flutter pub get` | Not run; SDK unavailable |
| `flutter analyze --no-fatal-infos` | Not run; SDK unavailable |
| `flutter test` | Not run; SDK unavailable |
| Release APK build | Not run; SDK/CI unavailable |
| Rendered phone/landscape/large-text screenshots | Not produced; Flutter rendering unavailable |
| Physical-device restart or update over existing APK | Not run; device unavailable |

### Runtime tests included, execution pending

`test/illustrated_map_test.dart` adds original asset loading/dimensions,
projection with both kinds of letterboxing, pin alignment and actual selection
after focus/pan, zoom/fit behavior, all ten fresh-profile states, locked navigation,
isolated coming-later behavior, sequential entry to every prefecture, persistence
across reopened services, opening all 42 locations and ten readings including
long final cards, shared radical panels, reading kana/English after a furigana
change, and narrow/typical phone and landscape layouts at normal and 2× text.

The four package integration test files are retained. They cover the actual
loader and shared references, question balance/pass threshold, failed-test gates,
modern place names, alternate readings and passage context. Existing global
furigana and lesson swipe/preview tests remain. None of these Flutter checks is
reported as passed without execution.

## Changed paths

- `content/packs/`: completed Hokkaido plus nine new prefecture packs.
- `content/journey_index.json`: added journeys 8–10 and recalibrated all ten anchors.
- `assets/maps/japan_journey_map.png`, `pubspec.yaml`: original offline artwork and asset registration.
- `lib/map/japan_map_screen.dart`, new `lib/map/illustrated_journey_map.dart`: country view and selection/navigation.
- `test/loader_test.dart`, `test/second_pack_test.dart`, `tool/tests/test_validate_content.py`:
  installer-reviewed fixture isolation and inventory updates.
- Four added package integration test files, new `test/illustrated_map_test.dart`,
  updated `test/widget_test.dart`: integration and map regression checks.
- `.github/workflows/ci.yml`: strict content gate; pinned build setup retained.
- `README.md`, this report: current release description and actual verification status.

## Build and test the delivered source

Extract the ZIP and use the `n5_kanji_journey` folder as the repository root.
Include `.github/workflows/ci.yml` when updating GitHub. Do not nest the app
folder inside the existing repository root. Push the source to trigger the
existing workflow: Python 3.12 → Flutter 3.35.0 analysis/tests → Java 17 release
APK, using the preserved signing key. The successful build artifact is
`n5-kanji-journey-apk`, containing `app-release.apk`.

For the same local checks with Flutter 3.35.0 and Java 17 installed:

```bash
python3 tool/validate_content.py --sync-assets --strict
python3 -m unittest discover -s tool/tests -v
flutter pub get
flutter analyze --no-fatal-infos
flutter test
bash tool/bootstrap_android.sh
mkdir -p ~/.android
cp tool/debug.keystore ~/.android/debug.keystore
flutter build apk --release
```

To repeat source audits, extract the original package ZIPs alongside the app and
run each package's `audit_package.py --root ../n5_kanji_journey` from its extracted
implementation directory. Do not rerun earlier installers over the final state
just to repeat an audit.

Before distribution, finish the pending CI checks and inspect the map at 320px
and 390px phone widths, landscape and large text. Test touch selection after
zoom/pan, long lesson cards, reading help and back/embedded-exit navigation.
On an existing installation, complete/record progress, install the new APK with
the same signer, and reopen it to confirm settings and history survive. On a
fresh profile, confirm Hokkaido-only availability, failed-test blocking and
successive progression through Gunma.
