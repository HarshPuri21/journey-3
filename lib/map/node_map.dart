import 'package:flutter/material.dart';

import '../core/math_utils.dart';
import '../package_system/pack_models.dart';

enum NodeState { available, completed, locked, comingLater }

class MapNode {
  const MapNode({
    required this.id,
    required this.label,
    required this.position,
    required this.state,
    this.number,
    this.sublabel,
  });
  final String id;
  final String label;
  final String? sublabel;
  final int? number;
  final MapPoint position;
  final NodeState state;
}

/// One reusable "stations on a route" view. It draws BOTH the country map
/// (nodes = prefectures) and a prefecture mini-map (nodes = chapters), so
/// neither screen knows how to draw a map. Phase 1 is a schematic; real
/// boundary artwork can replace the backdrop later without touching callers.
class NodeMapView extends StatelessWidget {
  const NodeMapView({super.key, required this.nodes, required this.onTap, this.aspectRatio = 0.8});

  final List<MapNode> nodes;
  final void Function(MapNode node) onTap;
  final double aspectRatio; // width / height

  static const double _nodeWidth = 92;
  static const double _nodeHeight = 84;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : maxW / aspectRatio;
        final w = maxW < maxH * aspectRatio ? maxW : maxH * aspectRatio;
        final h = w / aspectRatio;
        final cs = Theme.of(context).colorScheme;
        return Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 3,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [cs.primaryContainer.withValues(alpha: 0.35), cs.surfaceContainerHighest.withValues(alpha: 0.4)],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoutePainter(
                        [for (final n in nodes) Offset(n.position.x * w, n.position.y * h)],
                        cs.outline.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  for (final n in nodes)
                    Positioned(
                      left: clampD(n.position.x * w - _nodeWidth / 2, 0.0, clampD(w - _nodeWidth, 0.0, w)),
                      top: clampD(n.position.y * h - 28, 0.0, clampD(h - _nodeHeight, 0.0, h)),
                      width: _nodeWidth,
                      height: _nodeHeight,
                      child: _NodeWidget(node: n, onTap: () => onTap(n)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points, this.color);
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.points != points || old.color != color;
}

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({required this.node, required this.onTap});
  final MapNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (node.state) {
      NodeState.available => (cs.primary, cs.onPrimary, null),
      NodeState.completed => (cs.tertiary, cs.onTertiary, Icons.check),
      NodeState.locked => (cs.surfaceContainerHighest, cs.outline, Icons.lock_outline),
      NodeState.comingLater => (cs.surfaceContainerHigh, cs.outline, Icons.hourglass_empty),
    };
    return GestureDetector(
      key: ValueKey('node-${node.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: bg,
            foregroundColor: fg,
            child: icon != null
                ? Icon(icon, size: 20)
                : Text(node.number?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Text(
            node.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, color: node.state == NodeState.comingLater ? cs.outline : cs.onSurface),
          ),
          if (node.sublabel != null)
            Text(node.sublabel!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
