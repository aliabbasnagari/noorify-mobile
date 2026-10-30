import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated 3-bar "now playing" indicator, swapped in for a track number
/// when that row is the current track (documentation/07-UI-DESIGN-SYSTEM.md
/// §5). Bars continuously rise and fall while [playing] is true, staggered
/// so they don't move in lockstep, and freeze at a low height when false.
class PlayingBars extends StatefulWidget {
  const PlayingBars({super.key, required this.playing, this.color});

  final bool playing;
  final Color? color;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars>
    with SingleTickerProviderStateMixin {
  static const _frozenHeight = 0.25;

  // Phase offsets (as a fraction of one cycle) so the three bars don't move
  // in lockstep.
  static const _phases = [0.0, 0.55, 0.28];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PlayingBars old) {
    super.didUpdateWidget(old);
    if (widget.playing && !old.playing) {
      _controller.repeat();
    } else if (!widget.playing && old.playing) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 18,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [for (final phase in _phases) _bar(color, phase)],
        ),
      ),
    );
  }

  Widget _bar(Color color, double phase) {
    final heightFactor = widget.playing
        ? _frozenHeight +
            (1 - _frozenHeight) *
                (math.sin(2 * math.pi * (_controller.value + phase)) + 1) /
                2
        : _frozenHeight;
    return Container(
      width: 3,
      height: 16 * heightFactor,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
    );
  }
}
