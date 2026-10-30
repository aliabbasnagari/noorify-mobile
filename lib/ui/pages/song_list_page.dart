import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/sync_controller.dart';
import '../util.dart';
import '../widgets/song_tile.dart';

/// Flat list of every song, backed by [SyncController]'s library cache
/// (the same local database smart playlists are evaluated against).
class SongListPage extends StatelessWidget {
  const SongListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final player = context.read<PlayerController>();
    final songs = sync.songs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Songs'),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              tooltip: 'Shuffle all',
              icon: const Icon(Icons.shuffle),
              onPressed: () => player.playSongs(songs, shuffle: true),
            ),
        ],
      ),
      body: songs.isEmpty
          ? _EmptyState(sync: sync)
          : _SongList(songs: songs, player: player),
    );
  }
}

class _SongList extends StatelessWidget {
  const _SongList({required this.songs, required this.player});

  final List<Song> songs;
  final PlayerController player;

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: songs.length,
        itemBuilder: (_, i) => SongTile(
          song: songs[i],
          onTap: () => player.playSongs(songs, index: i),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.sync});

  final SyncController sync;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sync.isSyncing
                    ? 'Syncing… ${sync.songs.length} songs so far'
                    : (sync.error != null
                        ? (isConnectivityError(sync.error!)
                            ? "You're offline — sync needs a connection to your server."
                            : 'Sync failed: ${sync.error}')
                        : 'Sync your library to browse all songs here.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (!sync.isSyncing)
                FilledButton.tonal(
                    onPressed: sync.sync, child: const Text('Sync now')),
            ],
          ),
        ),
      );
}
