/// Tiny inline markup used in all content text:
///   {漢字|かんじ}  ruby (furigana) - base text + reading
///   **bold**       emphasis
/// Malformed markup degrades to literal text; it never throws.
class MarkupSegment {
  const MarkupSegment(this.text, {this.reading, this.bold = false});
  final String text;
  final String? reading;
  final bool bold;
}

List<MarkupSegment> parseMarkup(String input) {
  final out = <MarkupSegment>[];
  final buf = StringBuffer();
  var bold = false;

  void flush() {
    if (buf.isNotEmpty) {
      out.add(MarkupSegment(buf.toString(), bold: bold));
      buf.clear();
    }
  }

  var i = 0;
  while (i < input.length) {
    if (input.startsWith('**', i)) {
      flush();
      bold = !bold;
      i += 2;
      continue;
    }
    if (input[i] == '{') {
      final close = input.indexOf('}', i + 1);
      if (close != -1) {
        final inner = input.substring(i + 1, close);
        final bar = inner.indexOf('|');
        if (bar > 0 &&
            bar < inner.length - 1 &&
            !inner.contains('{') &&
            inner.indexOf('|', bar + 1) == -1) {
          flush();
          out.add(MarkupSegment(inner.substring(0, bar),
              reading: inner.substring(bar + 1), bold: bold));
          i = close + 1;
          continue;
        }
      }
    }
    buf.write(input[i]);
    i++;
  }
  flush();
  return out;
}

/// The text without any markup or readings (what a learner would copy).
String stripMarkup(String input) => parseMarkup(input).map((s) => s.text).join();

/// The text with ruby readings in parentheses - handy for logs and tests.
String markupToPlainWithReadings(String input) => parseMarkup(input)
    .map((s) => s.reading == null ? s.text : '${s.text}(${s.reading})')
    .join();
