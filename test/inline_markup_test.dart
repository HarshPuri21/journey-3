import 'package:flutter_test/flutter_test.dart';
import 'package:n5_kanji_journey/core/inline_markup.dart';

void main() {
  test('parses ruby and bold', () {
    final segs = parseMarkup('これは**{北海道|ほっかいどう}**です。');
    expect(segs.map((s) => s.text).join(), 'これは北海道です。');
    final ruby = segs.firstWhere((s) => s.reading != null);
    expect(ruby.text, '北海道');
    expect(ruby.reading, 'ほっかいどう');
    expect(ruby.bold, isTrue);
  });

  test('stripMarkup removes readings', () {
    expect(stripMarkup('{札幌|さっぽろ}は{北海道|ほっかいどう}です。'), '札幌は北海道です。');
    expect(markupToPlainWithReadings('{日本|にほん}'), '日本(にほん)');
  });

  test('malformed markup degrades to literal text and never throws', () {
    expect(stripMarkup('broken {北海道|'), 'broken {北海道|');
    expect(stripMarkup('{|x}'), '{|x}');
    expect(stripMarkup('{a|b|c}'), '{a|b|c}');
    expect(stripMarkup(''), '');
  });
}
