import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/star_controller.dart';
import '../routing/navigation.dart';
import '../widgets/cover_art.dart';
import '../widgets/seek_bar.dart';

/// The wide layout's bottom player: what is playing on the left, transport and
/// a seek bar in the middle, and queue, volume and full-screen controls on the
/// right. It is always present; with nothing queued the controls are disabled.
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  static const height = 88.0;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(flex: 3, child: _NowPlayingInfo(song: song)),
            Expanded(flex: 4, child: _Transport(player: player, song: song)),
            Expanded(flex: 3, child: _RightControls(player: player)),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingInfo extends StatelessWidget {
  const _NowPlayingInfo({required this.song});

  final Song? song;

  @override
  Widget build(BuildContext context) {
    final song = this.song;
    if (song == null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final starred =
        context.select<StarController, bool>((s) => s.isStarred(song));

    return Row(
      children: [
        CoverArt(
            coverArt: song.coverArt, size: 56, requestSize: 112, radius: 4),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                song.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: starred ? 'Remove from favorites' : 'Add to favorites',
          icon: Icon(
            starred ? Icons.favorite : Icons.favorite_border,
            color: starred ? scheme.primary : null,
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
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.player, required this.song});

  final PlayerController player;
  final Song? song;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = player.hasQueue;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Shuffle',
                icon: Icon(Icons.shuffle,
                    color: player.shuffleEnabled ? scheme.primary : null),
                onPressed: enabled ? player.toggleShuffle : null,
              ),
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.skip_previous),
                onPressed: enabled ? player.previous : null,
              ),
              if (player.isBuffering)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton.filled(
                  tooltip: player.isPlaying ? 'Pause' : 'Play',
                  icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.onSurface,
                    foregroundColor: scheme.surface,
                  ),
                  onPressed: enabled ? player.togglePlay : null,
                ),
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.skip_next),
                onPressed: enabled ? player.next : null,
              ),
              IconButton(
                tooltip: 'Repeat',
                icon: Icon(
                  player.loopMode == LoopMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                  color:
                      player.loopMode == LoopMode.off ? null : scheme.primary,
                ),
                onPressed: enabled ? player.cycleRepeat : null,
              ),
            ],
          ),
          SeekBar(
            player: player,
            fallbackSeconds: song?.duration ?? 0,
            inline: true,
          ),
        ],
      ),
    );
  }
}

class _RightControls extends StatelessWidget {
  const _RightControls({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();
    final queueOpen = settings.shell.queuePanelOpen;
    final volume = player.isMuted ? 0.0 : player.userVolume;
    final volumeIcon = volume == 0
        ? Icons.volume_off
        : volume < 0.5
            ? Icons.volume_down
            : Icons.volume_up;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: queueOpen ? 'Hide queue' : 'Show queue',
          icon:
              Icon(Icons.queue_music, color: queueOpen ? scheme.primary : null),
          onPressed: () => settings.updateShell(
              (s) => s.copyWith(queuePanelOpen: !s.queuePanelOpen)),
        ),
        IconButton(
          tooltip: player.isMuted ? 'Unmute' : 'Mute',
          icon: Icon(volumeIcon),
          onPressed: player.toggleMute,
        ),
        SizedBox(
          width: 110,
          child: Slider(
            value: volume,
            onChanged: player.setUserVolume,
          ),
        ),
        IconButton(
          tooltip: 'Open Now Playing',
          icon: const Icon(Icons.open_in_full),
          onPressed: player.hasQueue ? () => context.openNowPlaying() : null,
        ),
      ],
    );
  }
}
