import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/session_controller.dart';
import '../../subsonic/subsonic_client.dart';
import '../routing/navigation.dart';
import 'cover_art.dart';

/// A compact grid of the albums played most recently, at the top of Home: art
/// beside the title, one tap to open. Hidden when there is nothing to show
/// (nothing played yet, or the server could not be reached), because Home
/// already says so lower down.
class QuickAccessGrid extends StatefulWidget {
  const QuickAccessGrid({super.key, this.count = 8});

  final int count;

  @override
  State<QuickAccessGrid> createState() => _QuickAccessGridState();
}

class _QuickAccessGridState extends State<QuickAccessGrid> {
  late final Future<List<Album>> _future;

  @override
  void initState() {
    super.initState();
    final client = context.read<SessionController>().client!;
    _future = client.getAlbumList(AlbumListType.recent, size: widget.count);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Album>>(
        future: _future,
        builder: (context, snap) {
          final albums = snap.data;
          if (albums == null || albums.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LayoutBuilder(builder: (context, constraints) {
              const spacing = 8.0;
              // Two columns on a phone, more as the width allows.
              final columns = (constraints.maxWidth / 260).floor().clamp(2, 4);
              final tileWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final album in albums.take(columns * 2))
                    _QuickTile(album: album, width: tileWidth),
                ],
              );
            }),
          );
        },
      );
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.album, required this.width});

  final Album album;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: 56,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.openAlbum(album.id),
          child: Row(
            children: [
              CoverArt(
                  coverArt: album.coverArt, size: 56, requestSize: 112, radius: 0),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  album.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
