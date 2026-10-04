import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n5_kanji_journey/core/storage.dart';
import 'package:n5_kanji_journey/lessons/lesson_screen.dart';
import 'package:n5_kanji_journey/lessons/japanese_text.dart';
import 'package:n5_kanji_journey/lessons/knowledge_tiles.dart';
import 'package:n5_kanji_journey/map/illustrated_journey_map.dart';
import 'package:n5_kanji_journey/map/japan_map_screen.dart';
import 'package:n5_kanji_journey/map/node_map.dart';
import 'package:n5_kanji_journey/package_system/journey_loader.dart';
import 'package:n5_kanji_journey/package_system/pack_models.dart';
import 'package:n5_kanji_journey/package_system/pack_source.dart';
import 'package:n5_kanji_journey/prefectures/prefecture_screen.dart';
import 'package:n5_kanji_journey/prefectures/unlock_evaluator.dart';
import 'package:n5_kanji_journey/progress/progress_service.dart';

import 'support/disk_pack_source.dart';
import 'support/harness.dart';

const routeIds = ['hokkaido', 'aomori', 'iwate', 'miyagi', 'akita',
  'yamagata', 'fukushima', 'ibaraki', 'tochigi', 'gunma'];

Future<void> selectStop(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(const ValueKey('journey-stops')));
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey('route-stop-$id'));
  await tester.scrollUntilVisible(target, 160,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)));
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('original offline artwork is bundled with its exact aspect ratio', () async {
    final bytes = await rootBundle.load(japanMapAsset);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 941);
    expect(frame.image.height, 1672);
    frame.image.dispose();
    codec.dispose();
  });

  test('projection uses the contained image rectangle in both orientations', () {
    for (final viewport in [const Size(320, 700), const Size(844, 300)]) {
      final rect = japanMapImageRect(viewport);
      expect(rect.width / rect.height, closeTo(941 / 1672, 0.000001));
      expect(rect.center, viewport.center(Offset.zero));
      expect(japanMapAnchor(rect, const MapPoint(0, 0)), rect.topLeft);
      expect(japanMapAnchor(rect, const MapPoint(1, 1)), rect.bottomRight);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(viewport.width + 0.001));
      expect(rect.bottom, lessThanOrEqualTo(viewport.height + 0.001));
    }
    expect(japanMapImageRect(const Size(844, 300)).left, greaterThan(0));
    expect(japanMapImageRect(const Size(320, 700)).top, greaterThan(0));
  });

  testWidgets('pin selection, focus, pan and reset keep image and anchor aligned', (tester) async {
    String? tapped;
    const point = MapPoint(0.7, 0.4);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: IllustratedJourneyMap(
      nodes: const [MapNode(id: 'fixture', label: 'Fixture', sublabel: 'Fixture',
          number: 1, position: point, state: NodeState.available)],
      selectedId: 'fixture', onSelect: (id) => tapped = id,
    ))));
    await tester.pumpAndSettle();
    void checkAnchor() {
      final image = tester.getRect(find.byKey(const ValueKey('country-map-image')));
      final pin = tester.getCenter(find.byKey(const ValueKey('node-fixture')));
      expect((pin - japanMapAnchor(image, point)).distance, lessThan(0.01));
    }
    checkAnchor();
    await tester.tap(find.byKey(const ValueKey('map-focus')));
    await tester.pumpAndSettle();
    checkAnchor();
    await tester.tap(find.byKey(const ValueKey('node-fixture')));
    expect(tapped, 'fixture');
    final viewer = find.byKey(const ValueKey('country-map-viewer'));
    await tester.dragFrom(tester.getTopLeft(viewer) + const Offset(40, 40), const Offset(30, 20));
    await tester.pumpAndSettle();
    checkAnchor();
    tapped = null;
    await tester.tap(find.byKey(const ValueKey('node-fixture')));
    expect(tapped, 'fixture');
    final controller = tester.widget<InteractiveViewer>(viewer).transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
    await tester.tap(find.byKey(const ValueKey('map-zoom-in')));
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(4.5, 0.001));
    await tester.tap(find.byKey(const ValueKey('map-zoom-out')));
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(3, 0.001));
    await tester.tap(find.byKey(const ValueKey('map-fit')));
    await tester.pumpAndSettle();
    expect(controller.value, Matrix4.identity());
    checkAnchor();
    await tester.tap(find.byKey(const ValueKey('node-fixture')));
    expect(tapped, 'fixture');
  });

  test('all ten packs load cleanly with the exact handoff inventory', () async {
    final c = await JourneyLoader(DiskPackSource()).load();
    expect(c.diagnostics, isEmpty);
    expect(c.prefectures.map((p) => p.id), routeIds);
    expect(c.prefectures.every((p) => p.installed), isTrue);
    expect(c.packs, hasLength(10));
    var locations = 0;
    var cards = 0;
    var readingCards = 0;
    var questions = 0;
    for (final p in c.prefectures) {
      final pack = p.pack!;
      for (final chapter in pack.chapters) {
        for (final lesson in pack.lessonsOf(chapter)) {
          locations++;
          cards += lesson.cards.length;
          expect(lesson.isDraft, isFalse);
        }
      }
      readingCards += pack.readingLesson!.cards.length;
      questions += pack.questions.length;
    }
    expect(locations, 42);
    expect(cards, 495);
    expect(readingCards, 130);
    expect(questions, 600);
  });

  testWidgets('fresh profile states and the route list cannot open a locked stop', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    await tester.pumpWidget(harness(services, const JapanMapScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Available'), findsOneWidget);
    final nodes = tester.widget<IllustratedJourneyMap>(find.byType(IllustratedJourneyMap)).nodes;
    expect(nodes.map((n) => n.id), routeIds);
    expect(nodes.first.state, NodeState.available);
    expect(nodes.skip(1).every((n) => n.state == NodeState.locked), isTrue);
    await selectStop(tester, 'gunma');
    expect(find.text('Complete Tochigi to unlock this stop.'), findsOneWidget);
    final action = find.byKey(const ValueKey('enter-gunma'));
    await tester.ensureVisible(action);
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(PrefectureScreen), findsNothing);
    expect(find.byType(JapanMapScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('journey-stops')));
    await tester.pumpAndSettle();
    final list = find.byType(ListView);
    final state = tester.widget<ListTile>(find.byKey(const ValueKey('route-stop-gunma')));
    expect((state.subtitle! as Text).data, 'Locked');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('route-stop-hokkaido')), -160,
        scrollable: find.descendant(of: list, matching: find.byType(Scrollable)));
    expect((tester.widget<ListTile>(find.byKey(const ValueKey('route-stop-hokkaido'))).subtitle! as Text).data,
        'Available');
  });

  testWidgets('absent content is coming later in an isolated catalog', (tester) async {
    final files = (await tester.runAsync(() async => readAllContent()))!;
    files.removeWhere((path, _) => path.startsWith('content/packs/aomori/'));
    final services = (await tester.runAsync(() => loadTestServices(source: MemoryPackSource(files))))!;
    await tester.pumpWidget(harness(services, const JapanMapScreen()));
    await tester.pumpAndSettle();
    await selectStop(tester, 'aomori');
    expect(find.text('This prefecture is coming later.'), findsOneWidget);
    final action = find.byKey(const ValueKey('enter-aomori'));
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    expect(find.byType(PrefectureScreen), findsNothing);
  });

  testWidgets('each stop opens through the real navigation after its prerequisite passes', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    await tester.runAsync(services.settings.dismissKanaNotice);
    await tester.pumpWidget(harness(services, const JapanMapScreen()));
    await tester.pumpAndSettle();
    for (final id in routeIds) {
      await selectStop(tester, id);
      final action = find.byKey(ValueKey('enter-$id'));
      await tester.ensureVisible(action);
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(tester.widget<PrefectureScreen>(find.byType(PrefectureScreen)).prefectureId, id);
      Navigator.of(tester.element(find.byType(PrefectureScreen))).pop();
      await tester.pumpAndSettle();
      await tester.runAsync(() => services.progress.recordTestResult('$id/${id}_final',
          TestResult(21, 30, true, DateTime(2026, 10, 4))));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('selected-stop-status'))).data, 'Completed');
    }
  });

  test('expanded Hokkaido and the whole route retain progress after reopening', () async {
    final storage = MemoryStorage();
    final before = await loadTestServices(storage: storage);
    await before.progress.markLessonComplete('hokkaido/sapporo_l01');
    await before.progress.saveCardPosition('hokkaido/sapporo_l01', 5);
    await before.settings.dismissKanaNotice();
    await before.settings.setFurigana(false);
    for (final id in routeIds) {
      await before.progress.recordTestResult('$id/${id}_final', TestResult(21, 30, true,
          DateTime(2026, 10, 4), questionIds: ['saved-question'], missedRefs: ['kanji_北']));
    }
    final after = await loadTestServices(storage: storage);
    expect(after.progress.isLessonComplete('hokkaido/sapporo_l01'), isTrue);
    expect(after.progress.cardPosition('hokkaido/sapporo_l01'), 5);
    expect(after.settings.kanaNoticeDismissed, isTrue);
    expect(after.settings.furiganaEnabled, isFalse);
    final unlocks = UnlockEvaluator(after.catalog, after.progress);
    for (final id in routeIds) {
      expect(unlocks.isPrefectureComplete(id), isTrue);
      expect(after.progress.lastAttemptQuestionIds('$id/${id}_final'), ['saved-question']);
    }
    expect(after.progress.missedRefCounts()['kanji_北'], 10);
  });

  testWidgets('all 42 locations and ten readings open, including their long final cards', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    var opened = 0;
    await tester.runAsync(() async {
      for (final p in services.catalog.packs) {
        for (final l in p.lessons.values) {
          await services.progress.markLessonComplete(l.qualifiedId);
        }
        await services.progress.recordTestResult('${p.id}/${p.id}_final',
            TestResult(21, 30, true, DateTime(2026, 10, 4)));
      }
    });
    for (final id in routeIds) {
      for (final lesson in services.catalog.pack(id)!.lessons.values) {
        await tester.pumpWidget(harness(services, KeyedSubtree(key: ValueKey(lesson.qualifiedId),
            child: LessonScreen(lesson: lesson))));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('card-${lesson.cards.first.id}')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: lesson.qualifiedId);
        tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(lesson.cards.length - 1);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('card-${lesson.cards.last.id}')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '${lesson.qualifiedId} final card');
        opened++;
      }
    }
    expect(opened, 52);
  });

  testWidgets('shared radical panels and reading kana/English survive furigana changes', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    final lesson = services.catalog.pack('aomori')!.lessons['aomori_l01']!;
    final card = lesson.cards.firstWhere((c) => c.blocks.any((b) => b.type == 'radicalRef'));
    await tester.pumpWidget(harness(services, Scaffold(body: CardView(card: card))));
    await tester.pumpAndSettle();
    expect(find.byType(RadicalTile), findsWidgets);
    expect(find.byType(MissingEntity), findsNothing);
    expect(tester.takeException(), isNull);

    final reading = services.catalog.pack('gunma')!.readingLesson!.cards.first;
    final english = reading.blocks.firstWhere((b) => b.type == 'readingLine').str('en')!;
    final kana = reading.blocks.firstWhere((b) => b.type == 'text' &&
        (b.str('text') ?? '').startsWith('Kana:')).str('text')!;
    await tester.pumpWidget(harness(services, Scaffold(body: CardView(card: reading))));
    await tester.pumpAndSettle();
    expect(find.text(english), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is JapaneseText && w.markup == kana), findsOneWidget);
    await tester.runAsync(() => services.settings.setFurigana(false));
    await tester.pumpAndSettle();
    expect(find.text(english), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is JapaneseText && w.markup == kana), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 700), const Size(390, 844), const Size(844, 390)]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('country layout fits $size at text scale $textScale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final services = (await tester.runAsync(() => loadTestServices()))!;
        await tester.pumpWidget(harness(services, Builder(builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: const JapanMapScreen(),
        ))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final viewer = tester.getRect(find.byKey(const ValueKey('country-map-viewer')));
        final image = tester.getRect(find.byKey(const ValueKey('country-map-image')));
        expect(image.width / image.height, closeTo(japanMapAspectRatio, 0.00001));
        expect(viewer.contains(image.topLeft), isTrue);
        expect(image.right, lessThanOrEqualTo(viewer.right + 0.01));
        expect(image.bottom, lessThanOrEqualTo(viewer.bottom + 0.01));
        await tester.tap(find.byKey(const ValueKey('journey-stops')));
        await tester.pumpAndSettle();
        expect(find.text('Journey stops'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
