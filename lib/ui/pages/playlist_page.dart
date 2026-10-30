import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/session_controller.dart';
import '../../state/download_controller.dart';
import '../util.dart';
import '../widgets/offline_switch.dart';
import '../widgets/song_tile.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.playlistId, required this.name});

  final String playlistId;
  final String name;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  late Future<Playlist> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = context.read<SessionController>().client!.getPlaylist(widget.playlistId);

  Future<void> _delete() async {
    final client = context.read<SessionController>().client!;
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${widget.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await client.deletePlaylist(widget.playlistId);
      router.pop();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _removeAt(int index) async {
    final client = context.read<SessionController>().client!;
    try {
      await client.removeFromPlaylist(widget.playlistId, [index]);
      if (mounted) setState(_load);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
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
            return ErrorRetry(error: snap.error!, onRetry: () => setState(_load));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final songs = snap.data!.songs;
          if (songs.isEmpty) return const Center(child: Text('This playlist is empty'));
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => player.playSongs(songs),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => player.playSongs(songs, shuffle: true),
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle'),
                      ),
                    ),
                  ],
                ),
              ),
              OfflineSwitch(
                collection: OfflineCollection(
                  type: 'playlist',
                  id: widget.playlistId,
                  title: widget.name,
                ),
                songs: songs,
              ),
              for (var i = 0; i < songs.length; i++)
                SongTile(
                  song: songs[i],
                  onTap: () => player.playSongs(songs, index: i),
                  extraActions: [
                    PopupMenuItem<VoidCallback>(
                      value: () => _removeAt(i),
                      child: const Text('Remove from playlist'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
