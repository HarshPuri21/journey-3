import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/inline_markup.dart';
import '../settings/journey_settings.dart';

/// Renders Journey inline markup (`{漢字|かんじ}`, `**bold**`). Furigana follows
/// the single global setting in [JourneySettings] - lessons never decide this
/// themselves. With furigana OFF every ruby word becomes tappable: tap an
/// unfamiliar kanji to reveal its reading, tap again to hide it ("Assisted
/// Reading Mode"). Set [forceReadings] for places that teach the reading itself.
class JapaneseText extends StatefulWidget {
  const JapaneseText(this.markup, {super.key, this.style, this.textAlign, this.forceReadings = false});

  final String markup;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool forceReadings;

  @override
  State<JapaneseText> createState() => _JapaneseTextState();
}

class _JapaneseTextState extends State<JapaneseText> {
  final Set<int> _revealed = <int>{};

  @override
  void didUpdateWidget(JapaneseText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markup != widget.markup) _revealed.clear();
  }

  // The symmetric spacer below keeps the base text vertically centred on the
  // line, so it lines up with neighbouring plain text.
  Widget _ruby(String base, String reading, TextStyle s, double rubySize, double rubyHeight) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: rubyHeight,
          child: Text(
            reading,
            maxLines: 1,
            softWrap: false,
            style: s.copyWith(fontSize: rubySize, fontWeight: FontWeight.normal, height: 1.0),
          ),
        ),
        Text(base, style: s.copyWith(height: 1.1)),
        SizedBox(height: rubyHeight),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final furigana = widget.forceReadings || context.watch<JourneySettings>().furiganaEnabled;
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final size = base.fontSize ?? 14.0;
    final rubySize = size * 0.5;
    final rubyHeight = rubySize * 1.25;
    final segments = parseMarkup(widget.markup);
    final spans = <InlineSpan>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final s = seg.bold ? base.copyWith(fontWeight: FontWeight.bold) : base;
      final reading = seg.reading;
      if (reading == null) {
        spans.add(TextSpan(text: seg.text, style: s));
      } else if (furigana) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _ruby(seg.text, reading, s, rubySize, rubyHeight),
        ));
      } else {
        final shown = _revealed.contains(i);
        spans.add(WidgetSpan(
          alignment: shown ? PlaceholderAlignment.middle : PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              if (!_revealed.remove(i)) _revealed.add(i);
            }),
            child: shown ? _ruby(seg.text, reading, s, rubySize, rubyHeight) : Text(seg.text, style: s),
          ),
        ));
      }
    }
    return Text.rich(TextSpan(style: base, children: spans), textAlign: widget.textAlign);
  }
}
