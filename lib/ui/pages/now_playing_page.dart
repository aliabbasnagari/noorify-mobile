import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/star_controller.dart';
import '../routing/navigation.dart';
import '../widgets/art_hero_background.dart';
import '../widgets/cover_art.dart';
import '../widgets/seek_bar.dart';
import 'queue_sheet.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    final scheme = Theme.of(context).colorScheme;

    if (song == null) {
      // Queue was cleared (e.g. signed out) while this page was open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.closeOrHome();
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
          onPressed: () => context.closeOrHome(),
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
              child: LayoutBuilder(
                builder: (context, box) {
                  final art = AspectRatio(
                    aspectRatio: 1,
                    child: CoverArt(
                        coverArt: song.coverArt, requestSize: 800, radius: 20),
                  );
                  // A landscape tablet or desktop window puts the artwork
                  // beside the controls instead of stacking them, so neither
                  // is squeezed and the controls stay a sensible width.
                  if (box.maxWidth >= _sideBySideWidth &&
                      box.maxWidth > box.maxHeight * 1.2) {
                    return Row(
                      children: [
                        Expanded(flex: 5, child: Center(child: art)),
                        const SizedBox(width: 48),
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: _Details(song: song, player: player),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          Expanded(child: Center(child: art)),
                          const SizedBox(height: 16),
                          _Details(song: song, player: player),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The narrowest width at which the artwork and controls sit side by side.
const _sideBySideWidth = 840.0;

/// The title, artist, seek bar and transport controls.
class _Details extends StatelessWidget {
  const _Details({required this.song, required this.player});

  final Song song;
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(song.title, style: textTheme.headlineSmall, maxLines: 2),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            song.artist ?? '',
            style:
                textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        SeekBar(player: player, fallbackSeconds: song.duration),
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
                color: player.loopMode == LoopMode.off ? null : scheme.primary,
              ),
              onPressed: player.cycleRepeat,
            ),
          ],
        ),
      ],
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
