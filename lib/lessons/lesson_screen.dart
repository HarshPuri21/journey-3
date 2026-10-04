import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/journey_scaffold.dart';
import '../core/math_utils.dart';
import '../progress/progress_service.dart';
import 'block_renderers.dart';
import 'lesson_models.dart';

enum _Driver { none, pages, strip }

/// Renders ANY lesson from data: a swipeable sequence of cards plus a
/// card-preview strip. The strip and the pages are two views of one position:
/// dragging either moves both live, like an Android gallery.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  static const double _itemExtent = 76;

  late final PageController _pages;
  late final ScrollController _strip;
  late final ProgressService _progress;
  _Driver _driver = _Driver.none;
  int _current = 0;
  int _snapToken = 0;

  int get _count => widget.lesson.cards.length;

  @override
  void initState() {
    super.initState();
    _progress = context.read<ProgressService>();
    final saved = _progress.cardPosition(widget.lesson.qualifiedId);
    _current = _count == 0 ? 0 : clampI(saved, 0, _count - 1);
    _pages = PageController(initialPage: _current)..addListener(_onPagesScrolled);
    _strip = ScrollController(initialScrollOffset: _current * _itemExtent)..addListener(_onStripScrolled);
    // Not during build: this notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _progress.markLessonStarted(widget.lesson.qualifiedId);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _strip.dispose();
    super.dispose();
  }

  void _onPagesScrolled() {
    if (!_pages.hasClients || _count == 0) return;
    final page = _pages.page;
    if (page == null) return;
    final idx = clampI(page.round(), 0, _count - 1);
    if (idx != _current) {
      setState(() => _current = idx);
      _progress.saveCardPosition(widget.lesson.qualifiedId, idx);
    }
    if (_driver != _Driver.strip && _strip.hasClients) {
      final target = clampD(page * _itemExtent, 0.0, _strip.position.maxScrollExtent);
      if ((_strip.offset - target).abs() > 0.1) _strip.jumpTo(target);
    }
  }

  void _onStripScrolled() {
    if (_driver != _Driver.strip || !_pages.hasClients) return;
    final viewport = _pages.position.viewportDimension;
    final target = (_strip.offset / _itemExtent) * viewport;
    _pages.jumpTo(clampD(target, 0.0, _pages.position.maxScrollExtent));
  }

  bool _onPagesNotification(ScrollNotification n) {
    if (n.metrics.axis != Axis.horizontal || n.depth != 0) return false;
    if (n is ScrollStartNotification && _driver == _Driver.none) {
      _driver = _Driver.pages;
    } else if (n is ScrollEndNotification && _driver == _Driver.pages) {
      _driver = _Driver.none;
    }
    return false;
  }

  bool _onStripNotification(ScrollNotification n) {
    if (n.metrics.axis != Axis.horizontal) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _snapToken++;
      _driver = _Driver.strip;
    } else if (n is ScrollEndNotification && _driver == _Driver.strip) {
      _snapStrip();
    }
    return false;
  }

  void _snapStrip() {
    final index = clampI((_strip.offset / _itemExtent).round(), 0, math.max(0, _count - 1));
    final target = index * _itemExtent;
    if ((_strip.offset - target).abs() < 0.5) {
      _driver = _Driver.none;
      return;
    }
    final token = ++_snapToken;
    _strip
        .animateTo(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOut)
        .whenComplete(() {
      if (token == _snapToken) _driver = _Driver.none;
    });
  }

  void _goTo(int index) {
    if (index < 0 || index >= _count || !_pages.hasClients) return;
    _pages.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _finish() async {
    final lesson = widget.lesson;
    await _progress.markLessonComplete(lesson.qualifiedId);
    if (!mounted) return;
    final c = lesson.completion;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c?.title ?? 'Lesson complete'),
        content: c?.nextText == null ? null : Text(c!.nextText!),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Continue'))],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    if (_count == 0) {
      return JourneyScaffold(title: lesson.title, body: const Center(child: Text('This lesson has no cards yet.')));
    }
    final isLast = _current == _count - 1;
    return JourneyScaffold(
      title: lesson.title,
      body: Column(
        children: [
          LinearProgressIndicator(value: (_current + 1) / _count, minHeight: 3),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onPagesNotification,
              child: PageView.builder(
                controller: _pages,
                itemCount: _count,
                itemBuilder: (context, i) => CardView(key: ValueKey('card-${lesson.cards[i].id}'), card: lesson.cards[i]),
              ),
            ),
          ),
          if (isLast)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('finish-lesson'),
                  onPressed: _finish,
                  icon: const Icon(Icons.check),
                  label: const Text('Complete lesson'),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 84,
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('prev-card'),
                    tooltip: 'Previous card',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _current > 0 ? () => _goTo(_current - 1) : null,
                  ),
                  Expanded(child: _buildStrip()),
                  IconButton(
                    key: const ValueKey('next-card'),
                    tooltip: 'Next card',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: !isLast ? () => _goTo(_current + 1) : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrip() {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePad = math.max(0.0, (constraints.maxWidth - _itemExtent) / 2);
        return NotificationListener<ScrollNotification>(
          onNotification: _onStripNotification,
          child: ListView.builder(
            controller: _strip,
            scrollDirection: Axis.horizontal,
            itemExtent: _itemExtent,
            padding: EdgeInsets.symmetric(horizontal: sidePad),
            itemCount: _count,
            itemBuilder: (context, i) {
              final selected = i == _current;
              final card = widget.lesson.cards[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _goTo(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Container(
                    key: ValueKey(selected ? 'strip-$i-selected' : 'strip-$i'),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: selected ? cs.onPrimaryContainer : cs.onSurface)),
                        Text(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 8, height: 1.1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// One card. Always scrollable so a small screen can never overflow; cards
/// that are not marked `scroll` are vertically centred when they fit.
class CardView extends StatelessWidget {
  const CardView({super.key, required this.card});
  final LessonCard card;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.title, style: t.labelLarge?.copyWith(color: cs.primary, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        for (final b in card.blocks) buildContentBlock(context, b),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = math.max(0.0, constraints.maxHeight - 40);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: card.scroll ? Align(alignment: Alignment.topCenter, child: content) : Center(child: content),
          ),
        );
      },
    );
  }
}
