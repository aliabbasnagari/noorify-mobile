import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/star_controller.dart';
import '../util.dart';
import '../widgets/art_hero_background.dart';
import '../widgets/cover_art.dart';
import 'queue_sheet.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (song == null) {
      // Queue was cleared (e.g. signed out) while this page was open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold();
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(song.album ?? 'Now playing',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        actions: [
          _FavoriteButton(song: song),
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music),
            onPressed: () => showQueueSheet(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ArtHeroBackground(
                imageUrl: player.coverUri(song.coverArt, size: 800)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CoverArt(
                            coverArt: song.coverArt,
                            requestSize: 800,
                            radius: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(song.title,
                        style: textTheme.headlineSmall, maxLines: 2),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      song.artist ?? '',
                      style: textTheme.titleMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SeekBar(player: player, fallbackSeconds: song.duration),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Shuffle',
                        icon: Icon(
                          Icons.shuffle,
                          color: player.shuffleEnabled ? scheme.primary : null,
                        ),
                        onPressed: player.toggleShuffle,
                      ),
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.skip_previous),
                        onPressed: player.previous,
                      ),
                      _PlayButton(player: player),
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.skip_next),
                        onPressed: player.next,
                      ),
                      IconButton(
                        tooltip: 'Repeat',
                        icon: Icon(
                          player.loopMode == LoopMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: player.loopMode == LoopMode.off
                              ? null
                              : scheme.primary,
                        ),
                        onPressed: player.cycleRepeat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final starred =
        context.select<StarController, bool>((s) => s.isStarred(song));
    return IconButton(
      tooltip: starred ? 'Remove from favorites' : 'Add to favorites',
      icon: Icon(
        starred ? Icons.favorite : Icons.favorite_border,
        color: starred ? Theme.of(context).colorScheme.primary : null,
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await context.read<StarController>().toggle(song);
        } on Object catch (e) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('$e')));
        }
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    if (player.isBuffering) {
      return const SizedBox(
        width: 72,
        height: 72,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return IconButton.filled(
      iconSize: 40,
      padding: const EdgeInsets.all(16),
      icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
      onPressed: player.togglePlay,
    );
  }
}

class _PositionData {
  const _PositionData(this.position, this.duration);

  final Duration position;
  final Duration duration;
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player, required this.fallbackSeconds});

  final PlayerController player;
  final int fallbackSeconds;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// Slider value (ms) while the user is dragging; null otherwise.
  double? _dragging;

  late final Stream<_PositionData> _stream;

  @override
  void initState() {
    super.initState();
    // Built once so rebuilds (e.g. while dragging) don't resubscribe.
    _stream = Rx.combineLatest2<Duration, Duration?, _PositionData>(
      widget.player.positionStream,
      widget.player.durationStream,
      (p, d) =>
          _PositionData(p, d ?? Duration(seconds: widget.fallbackSeconds)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    return StreamBuilder<_PositionData>(
      stream: _stream,
      builder: (context, snap) {
        final data = snap.data ??
            _PositionData(
                Duration.zero, Duration(seconds: widget.fallbackSeconds));
        final maxMs = data.duration.inMilliseconds.toDouble();
        final posMs = (_dragging ?? data.position.inMilliseconds.toDouble())
            .clamp(0.0, maxMs > 0 ? maxMs : 1.0);
        return Column(
          children: [
            Slider(
              value: posMs,
              max: maxMs > 0 ? maxMs : 1.0,
              onChanged:
                  maxMs > 0 ? (v) => setState(() => _dragging = v) : null,
              onChangeEnd: (v) {
                player.seek(Duration(milliseconds: v.round()));
                setState(() => _dragging = null);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration((posMs / 1000).round())),
                  Text(formatDuration(data.duration.inSeconds)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
