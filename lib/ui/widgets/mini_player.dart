import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_controller.dart';
import '../pages/now_playing_page.dart';
import 'cover_art.dart';

/// Compact now-playing bar shown above the navigation bar, matching
/// `ui/`'s `player-bar-mobile` exactly (see reference-documents/07 §4.2 and
/// `ui/src/components/layout/player-bar.tsx`): a thin progress line,
/// continuously-spinning circular art that freezes on pause, and a single
/// filled green play/pause button — no previous/next buttons at phone width.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();

    // Resumes from the current angle rather than snapping back to upright.
    if (player.isPlaying) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const NowPlayingPage(),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snap) {
                final total = song.duration;
                final pos = snap.data?.inSeconds ?? 0;
                return LinearProgressIndicator(
                  minHeight: 2,
                  value: total > 0 ? (pos / total).clamp(0.0, 1.0) : null,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  RotationTransition(
                    turns: _spin,
                    child: ClipOval(
                      key: ValueKey(song.id),
                      child: CoverArt(
                        coverArt: song.coverArt,
                        size: 40,
                        requestSize: 96,
                        radius: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          song.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (player.isBuffering)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton.filled(
                      icon: Icon(
                          player.isPlaying ? Icons.pause : Icons.play_arrow),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.surface,
                      ),
                      onPressed: player.togglePlay,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
