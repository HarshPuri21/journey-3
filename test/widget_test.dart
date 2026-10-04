import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n5_kanji_journey/lessons/japanese_text.dart';
import 'package:n5_kanji_journey/lessons/lesson_screen.dart';
import 'package:n5_kanji_journey/map/japan_map_screen.dart';
import 'package:n5_kanji_journey/package_system/pack_source.dart';
import 'package:n5_kanji_journey/prefectures/prefecture_screen.dart';
import 'package:n5_kanji_journey/tests/test_screen.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled assets expose the Hokkaido pack (pubspec asset list is correct)', () async {
    final ids = await AssetPackSource().listPackIds();
    expect(ids, contains('hokkaido'));
    final index = await AssetPackSource().readString(kIndexPath);
    expect(index, contains('"journeyId"'));
  });

  testWidgets('map -> prefecture -> chapter -> lesson, all from data', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    await tester.pumpWidget(harness(services, const JapanMapScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('node-hokkaido')), findsOneWidget);
    expect(find.byKey(const ValueKey('node-aomori')), findsOneWidget);

    // Aomori is now installed, but its real prerequisite still blocks entry.
    await tester.tap(find.byKey(const ValueKey('node-aomori')));
    await tester.pump();
    expect(find.text('Complete Hokkaido to unlock this stop.'), findsOneWidget);
    final lockedEntry = find.byKey(const ValueKey('enter-aomori'));
    await tester.ensureVisible(lockedEntry);
    expect(tester.widget<FilledButton>(lockedEntry).onPressed, isNull);
    await tester.tap(lockedEntry);
    await tester.pumpAndSettle();
    expect(find.byType(PrefectureScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('node-hokkaido')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('enter-hokkaido')));
    await tester.tap(find.byKey(const ValueKey('enter-hokkaido')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node-sapporo')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('node-sapporo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-sapporo_l01')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lesson-sapporo_l01')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('card-welcome_to_hokkaido')), findsOneWidget);
  });

  group('lesson screen', () {
    testWidgets('swiping the cards moves the preview strip', (tester) async {
      final services = (await tester.runAsync(() => loadTestServices()))!;
      final lesson = services.catalog.lesson('hokkaido', 'sapporo_l01')!;
      await tester.pumpWidget(harness(services, LessonScreen(lesson: lesson)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('strip-0-selected')), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('strip-1-selected')), findsOneWidget);
      expect(find.byKey(ValueKey('card-${lesson.cards[1].id}')), findsOneWidget);
    });

    testWidgets('tapping a preview jumps to that card', (tester) async {
      final services = (await tester.runAsync(() => loadTestServices()))!;
      final lesson = services.catalog.lesson('hokkaido', 'sapporo_l01')!;
      await tester.pumpWidget(harness(services, LessonScreen(lesson: lesson)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('strip-3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('strip-3-selected')), findsOneWidget);
      expect(find.byKey(ValueKey('card-${lesson.cards[3].id}')), findsOneWidget);
    });

    testWidgets('dragging the preview strip moves the cards with it', (tester) async {
      final services = (await tester.runAsync(() => loadTestServices()))!;
      final lesson = services.catalog.lesson('hokkaido', 'sapporo_l01')!;
      await tester.pumpWidget(harness(services, LessonScreen(lesson: lesson)));
      await tester.pumpAndSettle();

      await tester.drag(find.byKey(const ValueKey('strip-0-selected')), const Offset(-170, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('strip-0-selected')), findsNothing);
      expect(find.byKey(ValueKey('card-${lesson.cards[0].id}')), findsNothing);
    });
  });

  testWidgets('the Hokkaido test runs 30 questions and records the result', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    await tester.pumpWidget(harness(services, const TestScreen(packId: 'hokkaido', testId: 'hokkaido_final')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 30; i++) {
      expect(find.text('Question ${i + 1} of 30'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choice-a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('next-question')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('test-score')), findsOneWidget);
    final results = services.progress.testResults('hokkaido/hokkaido_final');
    expect(results, hasLength(1));
    expect(results.single.total, 30);
    expect(results.single.questionIds, hasLength(30));
  });

  testWidgets('with furigana off, tapping a word reveals its reading', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    await tester.runAsync(() => services.settings.setFurigana(false));
    await tester.pumpWidget(harness(services, const Scaffold(body: JapaneseText('{北海道|ほっかいどう}です'))));
    await tester.pumpAndSettle();
    expect(find.text('ほっかいどう'), findsNothing);
    await tester.tap(find.text('北海道'));
    await tester.pump();
    expect(find.text('ほっかいどう'), findsOneWidget);
    await tester.tap(find.text('北海道'));
    await tester.pump();
    expect(find.text('ほっかいどう'), findsNothing);
  });

  testWidgets('reading and test tiles stay locked until their rules are met', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    await tester.pumpWidget(harness(services, const PrefectureScreen(prefectureId: 'hokkaido')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reading-tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('test-hokkaido_final')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reading-tile')));
    await tester.pump();
    expect(find.textContaining('Finish all the location lessons'), findsOneWidget);
  });

  testWidgets('furigana is one global setting', (tester) async {
    final services = (await tester.runAsync(() => loadTestServices()))!;
    await tester.pumpWidget(harness(services, const Scaffold(body: JapaneseText('{北海道|ほっかいどう}です'))));
    await tester.pumpAndSettle();
    expect(find.text('ほっかいどう'), findsOneWidget);

    await tester.runAsync(() => services.settings.setFurigana(false));
    await tester.pump();
    expect(find.text('ほっかいどう'), findsNothing);
  });
}
