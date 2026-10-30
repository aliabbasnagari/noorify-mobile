import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/download_controller.dart';
import '../../state/player_controller.dart';
import '../../state/playlists_revision.dart';
import '../../state/session_controller.dart';
import '../util.dart';
import '../widgets/collection_page.dart';
import '../widgets/cover_art.dart';
import '../widgets/offline_switch.dart';
import '../widgets/song_tile.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.playlistId, required this.name});

  final String playlistId;

  /// The name known when the page was opened, shown until the playlist loads.
  final String name;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  late Future<Playlist> _future;

  /// Starts as the name passed in, then follows renames and the server's name.
  late String _name = widget.name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future =
      context.read<SessionController>().client!.getPlaylist(widget.playlistId);

  Future<void> _rename() async {
    final client = context.read<SessionController>().client!;
    final revision = context.read<PlaylistsRevision>();
    final name = await promptForText(context, 'Rename playlist', 'Name',
        initialText: _name);
    if (name == null || name == _name) return;
    try {
      await client.renamePlaylist(widget.playlistId, name);
      revision.bump();
      if (mounted) {
        setState(() {
          _name = name;
          _load();
        });
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete() async {
    final client = context.read<SessionController>().client!;
    final revision = context.read<PlaylistsRevision>();
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$_name"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await client.deletePlaylist(widget.playlistId);
      revision.bump();
      router.pop();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _removeAt(int index) async {
    final client = context.read<SessionController>().client!;
    final revision = context.read<PlaylistsRevision>();
    try {
      await client.removeFromPlaylist(widget.playlistId, [index]);
      revision.bump();
      if (mounted) setState(_load);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final client = context.read<SessionController>().client;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Rename playlist',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _rename,
          ),
          IconButton(
            tooltip: 'Delete playlist',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: FutureBuilder<Playlist>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorRetry(
                error: snap.error!, onRetry: () => setState(_load));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final playlist = snap.data!;
          final songs = playlist.songs;
          // The server's name wins once known (it may differ from the URL's).
          final name = playlist.name.isEmpty ? _name : playlist.name;
          final total = songs.fold<int>(0, (sum, s) => sum + s.duration);

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              CollectionHeader(
                type: 'Playlist',
                title: name,
                tintImage: playlist.coverArt == null
                    ? null
                    : client?.coverArtUrl(playlist.coverArt!, size: 300),
                artBuilder: (size) => playlist.coverArt == null
                    ? _PlaylistArt(size: size)
                    : CoverArt(
                        coverArt: playlist.coverArt,
                        size: size,
                        requestSize: 500,
                        radius: 6,
                      ),
                meta: Text(
                  songs.isEmpty
                      ? 'No songs yet'
                      : '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}'
                          ' • ${formatTotal(total)}',
                ),
              ),
              CollectionActions(
                onPlay: songs.isEmpty
                    ? null
                    : () => player.playSongs(songs, source: name),
                onShuffle: songs.isEmpty
                    ? null
                    : () => player.playSongs(songs, shuffle: true, source: name),
                trailing: [
                  OfflineToggleButton(
                    collection: OfflineCollection(
                      type: 'playlist',
                      id: widget.playlistId,
                      title: name,
                    ),
                    songs: songs,
                  ),
                ],
              ),
              if (songs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('This playlist is empty')),
                )
              else ...[
                const TrackTableHeader(),
                for (var i = 0; i < songs.length; i++)
                  SongTile(
                    song: songs[i],
                    onTap: () =>
                        player.playSongs(songs, index: i, source: name),
                    extraActions: [
                      PopupMenuItem<VoidCallback>(
                        value: () => _removeAt(i),
                        child: const Text('Remove from playlist'),
                      ),
                    ],
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The cover shown for a playlist the server has no art for.
class _PlaylistArt extends StatelessWidget {
  const _PlaylistArt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: scheme.secondaryContainer,
        ),
        child: Icon(Icons.queue_music,
            size: size * 0.4, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
