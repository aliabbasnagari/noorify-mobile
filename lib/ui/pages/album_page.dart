import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/download_controller.dart';
import '../../state/player_controller.dart';
import '../../state/session_controller.dart';
import '../adaptive/layout.dart';
import '../routing/navigation.dart';
import '../util.dart';
import '../widgets/album_widgets.dart';
import '../widgets/collection_page.dart';
import '../widgets/cover_art.dart';
import '../widgets/offline_switch.dart';
import '../widgets/song_tile.dart';

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
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
    final client = context.read<SessionController>().client;
    final songs = album.songs;
    final collection =
        OfflineCollection(type: 'album', id: album.id, title: album.name);

    final details = <Widget>[
      if (album.artist != null)
        InkWell(
          onTap: album.artistId == null
              ? null
              : () => context.openArtist(album.artistId!),
          child: Text(
            album.artist!,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      if (album.year != null) Text('${album.year}'),
      Text(songs.length == 1 ? '1 song' : '${songs.length} songs'),
      Text(formatTotal(album.duration)),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        CollectionHeader(
          // One-track releases are singles.
          type: songs.length == 1 ? 'Single' : 'Album',
          title: album.name,
          tintImage: album.coverArt == null
              ? null
              : client?.coverArtUrl(album.coverArt!, size: 300),
          artBuilder: (size) => CoverArt(
            coverArt: album.coverArt,
            size: size,
            requestSize: 500,
            radius: 6,
          ),
          meta: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              for (var i = 0; i < details.length; i++) ...[
                if (i > 0) const Text('•'),
                details[i],
              ],
            ],
          ),
        ),
        CollectionActions(
          onPlay: songs.isEmpty
              ? null
              : () => player.playSongs(songs, source: album.name),
          onShuffle: songs.isEmpty
              ? null
              : () => player.playSongs(songs,
                  shuffle: true, source: album.name),
          trailing: [
            OfflineToggleButton(collection: collection, songs: songs),
            IconButton(
              tooltip: 'Add album to playlist',
              iconSize: 28,
              icon: const Icon(Icons.playlist_add),
              onPressed: songs.isEmpty
                  ? null
                  : () => showAddToPlaylistSheet(context, songs),
            ),
          ],
        ),
        const TrackTableHeader(),
        for (var i = 0; i < songs.length; i++)
          SongTile(
            song: songs[i],
            showCover: false,
            showTrackNumber: true,
            onTap: () => player.playSongs(songs, index: i, source: album.name),
          ),
        if (album.artistId != null && album.artist != null)
          _MoreByArtist(
            artistId: album.artistId!,
            artistName: album.artist!,
            exceptAlbumId: album.id,
          ),
      ],
    );
  }
}

/// A shelf of the artist's other albums, under the track list. Hidden when
/// there are none, or if they can't be loaded: the album itself is the point
/// of the page.
class _MoreByArtist extends StatefulWidget {
  const _MoreByArtist({
    required this.artistId,
    required this.artistName,
    required this.exceptAlbumId,
  });

  final String artistId;
  final String artistName;
  final String exceptAlbumId;

  @override
  State<_MoreByArtist> createState() => _MoreByArtistState();
}

class _MoreByArtistState extends State<_MoreByArtist> {
  late final Future<Artist> _future;

  @override
  void initState() {
    super.initState();
    _future =
        context.read<SessionController>().client!.getArtist(widget.artistId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Artist>(
        future: _future,
        builder: (context, snap) {
          final others = [
            for (final a in snap.data?.albums ?? const <Album>[])
              if (a.id != widget.exceptAlbumId) a,
          ];
          if (others.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AdaptiveShelf(
              title: 'More by ${widget.artistName}',
              itemCount: others.length,
              showAllLabel: 'See discography',
              onShowAll: () => context.openArtist(widget.artistId),
              itemBuilder: (_, i, width) =>
                  AlbumCard(album: others[i], width: width),
            ),
          );
        },
      );
}
