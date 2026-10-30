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

  /// Whether the songs are shown as a list that can be dragged into order.
  bool _reordering = false;

  /// The songs in the order the user dragged them to, shown at once while the
  /// server is told. Null means the order the server last sent.
  List<Song>? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _order = null;
    _future = context
        .read<SessionController>()
        .client!
        .getPlaylist(widget.playlistId);
  }

  /// Moves a song to [newIndex] (its place once it has been lifted out, as
  /// `onReorderItem` reports it) and saves the new order. The list changes immediately; if
  /// the server refuses, it goes back to how it was and the error is shown.
  Future<void> _reorder(List<Song> songs, int oldIndex, int newIndex) async {
    if (newIndex == oldIndex) return;
    final client = context.read<SessionController>().client!;
    final moved = [...songs];
    moved.insert(newIndex, moved.removeAt(oldIndex));
    setState(() => _order = moved);
    try {
      await client.reorderPlaylist(widget.playlistId, [
        for (final s in moved) s.id,
      ]);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _order = songs);
      showError(context, e);
    }
  }

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
          final songs = _order ?? playlist.songs;
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
                    : () =>
                        player.playSongs(songs, shuffle: true, source: name),
                trailing: [
                  if (songs.length > 1)
                    IconButton(
                      tooltip:
                          _reordering ? 'Done reordering' : 'Reorder songs',
                      icon: Icon(_reordering ? Icons.check : Icons.swap_vert),
                      onPressed: () =>
                          setState(() => _reordering = !_reordering),
                    ),
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
              else if (_reordering)
                _ReorderList(
                  songs: songs,
                  onReorder: (from, to) => _reorder(songs, from, to),
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

/// The playlist's songs with a handle on each row to drag it into place.
class _ReorderList extends StatelessWidget {
  const _ReorderList({required this.songs, required this.onReorder});

  final List<Song> songs;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
        // The page itself scrolls; this list only lays its rows out.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: songs.length,
        onReorderItem: onReorder,
        itemBuilder: (context, i) => ListTile(
          key: ObjectKey(songs[i]),
          leading: SizedBox(
            width: 40,
            child: CoverArt(
                coverArt: songs[i].coverArt, size: 40, requestSize: 100),
          ),
          title: Text(songs[i].title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(songs[i].artist ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: ReorderableDragStartListener(
            index: i,
            child: const Tooltip(
              message: 'Drag to reorder',
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ),
        ),
      );
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
