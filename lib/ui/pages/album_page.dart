import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/session_controller.dart';
import '../util.dart';
import '../../state/download_controller.dart';
import '../widgets/cover_art.dart';
import '../widgets/offline_switch.dart';
import '../widgets/song_tile.dart';
import '../routing/navigation.dart';

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key, required this.albumId});

  final String albumId;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Future<Album> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future =
      context.read<SessionController>().client!.getAlbum(widget.albumId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Album>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorRetry(
                error: snap.error!, onRetry: () => setState(_load));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _AlbumBody(album: snap.data!);
        },
      ),
    );
  }
}

class _AlbumBody extends StatelessWidget {
  const _AlbumBody({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final textTheme = Theme.of(context).textTheme;
    final songs = album.songs;
    final meta = [
      if (album.year != null) '${album.year}',
      '${songs.length} songs',
      formatTotal(album.duration),
    ].join(' • ');

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CoverArt(
                  coverArt: album.coverArt,
                  size: 140,
                  requestSize: 400,
                  radius: 12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(album.name, style: textTheme.titleLarge, maxLines: 3),
                    if (album.artist != null)
                      InkWell(
                        onTap: album.artistId == null
                            ? null
                            : () => context.openArtist(album.artistId!),
                        child: Text(
                          album.artist!,
                          style: textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(meta, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: songs.isEmpty
                      ? null
                      : () => player.playSongs(songs, source: album.name),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: songs.isEmpty
                      ? null
                      : () => player.playSongs(songs,
                          shuffle: true, source: album.name),
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Shuffle'),
                ),
              ),
              IconButton(
                tooltip: 'Add album to playlist',
                icon: const Icon(Icons.playlist_add),
                onPressed: songs.isEmpty
                    ? null
                    : () => showAddToPlaylistSheet(context, songs),
              ),
            ],
          ),
        ),
        OfflineSwitch(
          collection:
              OfflineCollection(type: 'album', id: album.id, title: album.name),
          songs: songs,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < songs.length; i++)
          SongTile(
            song: songs[i],
            showCover: false,
            showTrackNumber: true,
            onTap: () => player.playSongs(songs, index: i, source: album.name),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
