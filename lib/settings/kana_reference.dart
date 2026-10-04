import 'package:flutter/material.dart';

const List<String> _hiragana = ['あいうえお', 'かきくけこ', 'さしすせそ', 'たちつてと', 'なにぬねの', 'はひふへほ', 'まみむめも', 'やゆよ', 'らりるれろ', 'わをん'];
const List<String> _katakana = ['アイウエオ', 'カキクケコ', 'サシスセソ', 'タチツテト', 'ナニヌネノ', 'ハヒフヘホ', 'マミムメモ', 'ヤユヨ', 'ラリルレロ', 'ワヲン'];
const List<List<String>> _romaji = [
  ['a', 'i', 'u', 'e', 'o'],
  ['ka', 'ki', 'ku', 'ke', 'ko'],
  ['sa', 'shi', 'su', 'se', 'so'],
  ['ta', 'chi', 'tsu', 'te', 'to'],
  ['na', 'ni', 'nu', 'ne', 'no'],
  ['ha', 'hi', 'fu', 'he', 'ho'],
  ['ma', 'mi', 'mu', 'me', 'mo'],
  ['ya', 'yu', 'yo'],
  ['ra', 'ri', 'ru', 're', 'ro'],
  ['wa', 'wo', 'n'],
];

/// Convenience cheat-sheet only - the kana curriculum lives elsewhere.
Future<void> showKanaReference(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.75,
      child: const KanaReferencePanel(),
    ),
  );
}

class KanaReferencePanel extends StatelessWidget {
  const KanaReferencePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'ひらがな'), Tab(text: 'カタカナ')]),
          Expanded(
            child: TabBarView(
              children: [
                _KanaGrid(rows: _hiragana),
                _KanaGrid(rows: _katakana),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KanaGrid extends StatelessWidget {
  const _KanaGrid({required this.rows});
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var r = 0; r < rows.length; r++) {
      final chars = rows[r].split('');
      final rom = _romaji[r];
      // 3-character rows (ya/yu/yo, wa/wo/n) sit in columns 1, 3 and 5.
      final cols = chars.length == 5 ? [0, 1, 2, 3, 4] : [0, 2, 4];
      for (var c = 0; c < 5; c++) {
        final i = cols.indexOf(c);
        cells.add(i < 0
            ? const SizedBox.shrink()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(chars[i], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
                  Text(rom[i], style: Theme.of(context).textTheme.labelSmall),
                ],
              ));
      }
    }
    return GridView.count(crossAxisCount: 5, childAspectRatio: 1.25, padding: const EdgeInsets.all(12), children: cells);
  }
}
