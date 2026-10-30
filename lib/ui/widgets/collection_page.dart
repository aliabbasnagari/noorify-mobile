import 'package:flutter/material.dart';

import '../adaptive/window_class.dart';
import 'art_hero_background.dart';

/// The top of an album, playlist or favorites page: the cover, what kind of
/// thing it is, a large title and a line of details, on a gradient tinted from
/// the cover's colour.
///
/// On a phone the cover is centred above the text; on wider windows it sits
/// beside it. Put it inside a page whose app bar is transparent and whose body
/// extends behind it (`extendBodyBehindAppBar`), so the gradient runs to the
/// top of the screen.
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    required this.artBuilder,
    required this.type,
    required this.title,
    this.meta,
    this.tintImage,
  });

  /// Builds the cover at the size the layout wants.
  final Widget Function(double size) artBuilder;

  /// "Album", "Single", "Playlist"...
  final String type;
  final String title;

  /// A line of details under the title (artist, year, track count...).
  final Widget? meta;

  /// The image the gradient takes its colour from (usually the cover); null
  /// leaves the neutral gradient.
  final Uri? tintImage;

  @override
  Widget build(BuildContext context) {
    final wide = !WindowClass.of(context).isCompact;
    final textTheme = Theme.of(context).textTheme;
    final artSize = wide ? 232.0 : 200.0;
    final side = wide ? 24.0 : 16.0;
    // Leave room for the (transparent) app bar the page draws over this.
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(type, style: textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: (wide ? textTheme.displaySmall : textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (meta != null) ...[const SizedBox(height: 8), meta!],
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: ArtHeroBackground(imageUrl: tintImage, height: double.infinity),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(side, top + 8, side, 16),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    artBuilder(artSize),
                    const SizedBox(width: 24),
                    Expanded(child: text),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: artBuilder(artSize)),
                    const SizedBox(height: 16),
                    text,
                  ],
                ),
        ),
      ],
    );
  }
}

/// The row under a [CollectionHeader]: a large Play button, Shuffle, and any
/// [trailing] actions (offline, add to playlist, ...).
class CollectionActions extends StatelessWidget {
  const CollectionActions({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.trailing = const [],
  });

  /// Null disables Play and Shuffle (nothing to play).
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = !WindowClass.of(context).isCompact;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 8, wide ? 24 : 12, 8),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: 'Play',
            iconSize: 32,
            padding: const EdgeInsets.all(12),
            style: IconButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            icon: const Icon(Icons.play_arrow),
            onPressed: onPlay,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Shuffle',
            iconSize: 28,
            icon: const Icon(Icons.shuffle),
            onPressed: onShuffle,
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// The column headings above a track list on wide windows: `#`, Title and the
/// duration clock. Phones, where the rows are cards, don't show it.
class TrackTableHeader extends StatelessWidget {
  const TrackTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    if (WindowClass.of(context).isCompact) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(color: scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 32, child: Center(child: Text('#', style: style))),
              const SizedBox(width: 16),
              Expanded(child: Text('Title', style: style)),
              Padding(
                padding: const EdgeInsets.only(right: 56),
                child: Icon(Icons.schedule,
                    size: 18, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}
