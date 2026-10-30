import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/session_controller.dart';
import '../adaptive/layout.dart';
import '../adaptive/window_class.dart';
import '../routing/navigation.dart';
import '../util.dart';
import '../widgets/album_widgets.dart';
import '../widgets/collection_page.dart';
import '../widgets/cover_art.dart';
import '../widgets/song_tile.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.artistId});

  final String artistId;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  late Future<Artist> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future =
      context.read<SessionController>().client!.getArtist(widget.artistId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<Artist>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorRetry(
                error: snap.error!, onRetry: () => setState(_load));
          }
          final artist = snap.data;
          if (artist == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ArtistBody(artist: artist);
        },
      ),
    );
  }
}

/// An artist's page: a header, the most popular songs, the albums, similar
/// artists and a biography. Only the albums come with the artist itself; the
/// rest load separately and are simply left out if the server has nothing or
/// the request fails, so the page never waits on (or breaks over) them.
class _ArtistBody extends StatefulWidget {
  const _ArtistBody({required this.artist});

  final Artist artist;

  @override
  State<_ArtistBody> createState() => _ArtistBodyState();
}

class _ArtistBodyState extends State<_ArtistBody> {
  /// Songs shown under Popular before "Show more".
  static const _previewCount = 5;
  static const _bioPreviewLength = 280;

  /// Null while loading; empty if there are none or the request failed.
  List<Song>? _top;
  ArtistInfo? _info;
  bool _showAllTop = false;
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    final client = context.read<SessionController>().client!;
    final artist = widget.artist;
    client.getTopSongs(artist.name, count: 10).then<void>(
      (songs) {
        if (mounted) setState(() => _top = songs);
      },
      onError: (Object _) {
        if (mounted) setState(() => _top = const []);
      },
    );
    client.getArtistInfo(artist.id).then<void>(
      (info) {
        if (mounted) setState(() => _info = info);
      },
      onError: (Object _) {
        if (mounted) setState(() => _info = const ArtistInfo());
      },
    );
  }

  /// Plays the artist's popular songs, or their first album when the server
  /// has no popularity data for them.
  Future<void> _play({bool shuffle = false}) async {
    final player = context.read<PlayerController>();
    final client = context.read<SessionController>().client!;
    final artist = widget.artist;
    var songs = _top ?? const <Song>[];
    if (songs.isEmpty && artist.albums.isNotEmpty) {
      try {
        songs = (await client.getAlbum(artist.albums.first.id)).songs;
      } on Object catch (e) {
        if (mounted) showError(context, e);
        return;
      }
    }
    if (songs.isEmpty) return;
    await player.playSongs(songs, shuffle: shuffle, source: artist.name);
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    final client = context.read<SessionController>().client;
    final player = context.read<PlayerController>();
    final wide = !WindowClass.of(context).isCompact;
    final side = wide ? 24.0 : 16.0;
    final top = _top ?? const <Song>[];
    final info = _info;
    final canPlay = artist.albums.isNotEmpty || top.isNotEmpty;
    final shownTop = _showAllTop ? top : top.take(_previewCount).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        CollectionHeader(
          type: 'Artist',
          title: artist.name,
          tintImage: artist.coverArt == null
              ? null
              : client?.coverArtUrl(artist.coverArt!, size: 300),
          artBuilder: (size) => ClipOval(
            child: CoverArt(
              coverArt: artist.coverArt,
              size: size,
              requestSize: 500,
              radius: 0,
            ),
          ),
          meta: Text(artist.albums.length == 1
              ? '1 album'
              : '${artist.albums.length} albums'),
        ),
        CollectionActions(
          onPlay: canPlay ? () => _play() : null,
          onShuffle: canPlay ? () => _play(shuffle: true) : null,
        ),
        if (top.isNotEmpty) ...[
          _Heading('Popular', side: side),
          for (var i = 0; i < shownTop.length; i++)
            SongTile(
              song: shownTop[i],
              onTap: () => player.playSongs(top, index: i, source: artist.name),
            ),
          if (top.length > _previewCount)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: side - 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _showAllTop = !_showAllTop),
                  child: Text(_showAllTop ? 'Show less' : 'Show more'),
                ),
              ),
            ),
        ],
        _Heading('Albums', side: side),
        if (artist.albums.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: const Text('No albums'),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: side),
            gridDelegate: ArtGridDelegate.of(context),
            itemCount: artist.albums.length,
            itemBuilder: (_, i) => AlbumCard(album: artist.albums[i]),
          ),
        if (info != null && info.similarArtists.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AdaptiveShelf(
              title: 'Fans also like',
              itemCount: info.similarArtists.length,
              itemBuilder: (_, i, width) =>
                  _ArtistCard(artist: info.similarArtists[i], width: width),
            ),
          ),
        if (info?.biography != null) ...[
          _Heading('About', side: side),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: _Biography(
              text: info!.biography!,
              expanded: _bioExpanded,
              previewLength: _bioPreviewLength,
              onToggle: () => setState(() => _bioExpanded = !_bioExpanded),
            ),
          ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.side});

  final String text;
  final double side;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(side, 16, side, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

/// A circular artist picture with the name under it, for the similar artists.
class _ArtistCard extends StatelessWidget {
  const _ArtistCard({required this.artist, required this.width});

  final Artist artist;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.openArtist(artist.id),
          child: Column(
            children: [
              ClipOval(
                child: CoverArt(
                  coverArt: artist.coverArt,
                  size: width,
                  requestSize: 300,
                  radius: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                'Artist',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

/// The biography, cut to a preview with a Read more / Show less button when it
/// is long.
class _Biography extends StatelessWidget {
  const _Biography({
    required this.text,
    required this.expanded,
    required this.previewLength,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final int previewLength;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final long = text.length > previewLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          expanded || !long ? text : '${text.substring(0, previewLength)}…',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (long)
          TextButton(
            onPressed: onToggle,
            child: Text(expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }
}
