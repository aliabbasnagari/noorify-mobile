import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../../state/player_controller.dart';
import '../util.dart';

class _PositionData {
  const _PositionData(this.position, this.duration);

  final Duration position;
  final Duration duration;
}

/// A draggable playback position slider with elapsed and total time.
///
/// By default the times sit under the slider (the full-screen player). With
/// [inline] they sit either side of a slimmer slider, as in the desktop player
/// bar. The slider follows the song while it plays, and seeks when released.
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.player,
    required this.fallbackSeconds,
    this.inline = false,
  });

  final PlayerController player;

  /// Duration to show until the player reports one, from the song's metadata.
  final int fallbackSeconds;
  final bool inline;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  /// Slider value (ms) while the user is dragging; null otherwise.
  double? _dragging;

  late final Stream<_PositionData> _stream;

  @override
  void initState() {
    super.initState();
    // Built once so rebuilds (e.g. while dragging) don't resubscribe. The
    // fallback is read when each event arrives, so a longer-lived bar (the
    // desktop player bar) follows the song as it changes.
    _stream = Rx.combineLatest2<Duration, Duration?, _PositionData>(
      widget.player.positionStream,
      widget.player.durationStream,
      (p, d) => _PositionData(p, d ?? _fallback),
    );
  }

  Duration get _fallback => Duration(seconds: widget.fallbackSeconds);

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    return StreamBuilder<_PositionData>(
      stream: _stream,
      builder: (context, snap) {
        final data = snap.data ?? _PositionData(Duration.zero, _fallback);
        final maxMs = data.duration.inMilliseconds.toDouble();
        final posMs = (_dragging ?? data.position.inMilliseconds.toDouble())
            .clamp(0.0, maxMs > 0 ? maxMs : 1.0);

        final slider = Slider(
          value: posMs,
          max: maxMs > 0 ? maxMs : 1.0,
          onChanged: maxMs > 0 ? (v) => setState(() => _dragging = v) : null,
          onChangeEnd: (v) {
            player.seek(Duration(milliseconds: v.round()));
            setState(() => _dragging = null);
          },
        );
        // One line always: a wrapped time would push the slider around.
        final elapsed = Text(
          formatDuration((posMs / 1000).round()),
          maxLines: 1,
          softWrap: false,
        );
        final total = Text(
          formatDuration(data.duration.inSeconds),
          maxLines: 1,
          softWrap: false,
        );

        if (widget.inline) {
          final small = Theme.of(context).textTheme.bodySmall;
          return Row(
            children: [
              SizedBox(
                width: 44,
                child: DefaultTextStyle.merge(
                  style: small,
                  textAlign: TextAlign.end,
                  child: elapsed,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: slider,
                ),
              ),
              SizedBox(
                width: 44,
                child: DefaultTextStyle.merge(style: small, child: total),
              ),
            ],
          );
        }

        return Column(
          children: [
            slider,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [elapsed, total],
              ),
            ),
          ],
        );
      },
    );
  }
}
