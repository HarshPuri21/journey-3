import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../package_system/pack_models.dart';
import 'node_map.dart';

const japanMapAsset = 'assets/maps/japan_journey_map.png';
const japanMapAspectRatio = 941 / 1672;

/// Coordinates belong to the artwork, excluding the viewport's letterboxing.
Rect japanMapImageRect(Size viewport) {
  final width = viewport.width < viewport.height * japanMapAspectRatio
      ? viewport.width
      : viewport.height * japanMapAspectRatio;
  final height = width / japanMapAspectRatio;
  return Rect.fromLTWH(
      (viewport.width - width) / 2, (viewport.height - height) / 2, width, height);
}

Offset japanMapAnchor(Rect imageRect, MapPoint point) =>
    imageRect.topLeft + Offset(point.x * imageRect.width, point.y * imageRect.height);

String nodeStatusLabel(NodeState state) => switch (state) {
      NodeState.available => 'Available',
      NodeState.completed => 'Completed',
      NodeState.locked => 'Locked',
      NodeState.comingLater => 'Coming later',
    };

IconData nodeStatusIcon(NodeState state) => switch (state) {
      NodeState.available => Icons.play_arrow,
      NodeState.completed => Icons.check,
      NodeState.locked => Icons.lock_outline,
      NodeState.comingLater => Icons.hourglass_empty,
    };

/// The country artwork and pins share one image-sized, transformed canvas.
/// Prefecture mini-maps continue to use the separate schematic NodeMapView.
class IllustratedJourneyMap extends StatefulWidget {
  const IllustratedJourneyMap({
    super.key,
    required this.nodes,
    required this.selectedId,
    required this.onSelect,
  });

  final List<MapNode> nodes;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<IllustratedJourneyMap> createState() => _IllustratedJourneyMapState();
}

class _IllustratedJourneyMapState extends State<IllustratedJourneyMap> {
  final _transform = TransformationController();
  Size _viewport = Size.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit() => _transform.value = Matrix4.identity();

  void _zoom(double factor) {
    if (_viewport.isEmpty) return;
    final center = _viewport.center(Offset.zero);
    final scene = _transform.toScene(center);
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(1.0, 6.0).toDouble();
    _transform.value = Matrix4.identity()
      ..translate(center.dx - scene.dx * scale, center.dy - scene.dy * scale)
      ..scale(scale);
  }

  void _focusSelected() {
    if (_viewport.isEmpty) return;
    final matches = widget.nodes.where((n) => n.id == widget.selectedId);
    if (matches.isEmpty) return;
    final anchor = japanMapAnchor(japanMapImageRect(_viewport), matches.first.position);
    final center = _viewport.center(Offset.zero);
    const scale = 3.0;
    _transform.value = Matrix4.identity()
      ..translate(center.dx - anchor.dx * scale, center.dy - anchor.dy * scale)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            if (_viewport != size) {
              final resized = !_viewport.isEmpty;
              _viewport = size;
              if (resized) WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fit();
              });
            }
            final imageRect = japanMapImageRect(size);
            // Keep visible targets separate at fit scale. Zoom enlarges the
            // same targets; the ordered stop list provides full-size controls.
            var pinSize = 20.0;
            for (var i = 0; i < widget.nodes.length; i++) {
              for (var j = i + 1; j < widget.nodes.length; j++) {
                final a = japanMapAnchor(imageRect, widget.nodes[i].position);
                final b = japanMapAnchor(imageRect, widget.nodes[j].position);
                pinSize = math.min(pinSize, (a - b).distance * 0.85);
              }
            }
            pinSize = math.max(6.0, pinSize);
            return ColoredBox(
              color: const Color(0xff0078ca),
              child: InteractiveViewer(
                key: const ValueKey('country-map-viewer'),
                transformationController: _transform,
                minScale: 1,
                maxScale: 6,
                boundaryMargin: const EdgeInsets.all(400),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(children: [
                    Positioned.fromRect(
                      rect: imageRect,
                      child: Stack(
                        key: const ValueKey('country-map-canvas'),
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              japanMapAsset,
                              key: const ValueKey('country-map-image'),
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                          for (final node in widget.nodes)
                            Positioned(
                              left: node.position.x * imageRect.width - pinSize / 2,
                              top: node.position.y * imageRect.height - pinSize / 2,
                              width: pinSize,
                              height: pinSize,
                              child: _MapPin(
                                node: node,
                                diameter: pinSize,
                                selected: node.id == widget.selectedId,
                                onTap: () => widget.onSelect(node.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(key: const ValueKey('map-zoom-out'), tooltip: 'Zoom out',
                onPressed: () => _zoom(1 / 1.5), icon: const Icon(Icons.remove)),
            IconButton(key: const ValueKey('map-zoom-in'), tooltip: 'Zoom in',
                onPressed: () => _zoom(1.5), icon: const Icon(Icons.add)),
            IconButton(key: const ValueKey('map-focus'), tooltip: 'Focus selected stop',
                onPressed: _focusSelected, icon: const Icon(Icons.location_searching)),
            IconButton(key: const ValueKey('map-fit'), tooltip: 'Fit whole map',
                onPressed: _fit, icon: const Icon(Icons.fit_screen)),
          ],
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.node, required this.diameter, required this.selected, required this.onTap});
  final MapNode node;
  final double diameter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (node.state) {
      NodeState.available => const Color(0xff1348a4),
      NodeState.completed => const Color(0xff0b6746),
      NodeState.locked => const Color(0xff394450),
      NodeState.comingLater => const Color(0xff655477),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Stop ${node.number}, ${node.label}, ${node.sublabel}, ${nodeStatusLabel(node.state)}',
      child: GestureDetector(
        key: ValueKey('node-${node.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? Colors.amberAccent : Colors.white,
                  width: math.min(selected ? 2.0 : 1.0, diameter / 10)),
            ),
            child: Center(
              child: node.state == NodeState.available
                  ? Text('${node.number}', textScaler: TextScaler.noScaling,
                      style: TextStyle(color: Colors.white, fontSize: diameter * 0.55, fontWeight: FontWeight.bold))
                  : Icon(nodeStatusIcon(node.state), size: diameter * 0.6, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
