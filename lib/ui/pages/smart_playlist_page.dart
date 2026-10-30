import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../smart/smart_filter.dart';
import '../../state/download_controller.dart';
import '../../state/player_controller.dart';
import '../../state/smart_playlist_store.dart';
import '../../state/sync_controller.dart';
import '../util.dart';
import '../widgets/song_tile.dart';
import '../routing/navigation.dart';

/// Evaluates a smart playlist against the synced library and lists the result.
class SmartPlaylistPage extends StatelessWidget {
  const SmartPlaylistPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final playlist = context.watch<SmartPlaylistStore>().byId(playlistId);
    if (playlist == null) {
      // Deleted while open.
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Playlist removed')));
    }
    final sync = context.watch<SyncController>();
    final downloads = context.read<DownloadController>();
    final player = context.read<PlayerController>();

    final List<Song> songs = playlist.filter.apply(
      sync.songs,
      SmartContext(isDownloaded: downloads.isDownloaded),
    );
    final total = songs.fold<int>(0, (sum, s) => sum + s.duration);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.title),
        actions: [
          IconButton(
            tooltip: 'Edit rules',
            icon: const Icon(Icons.tune),
            onPressed: () => context.editSmartPlaylist(playlist.id),
          ),
        ],
      ),
      body: sync.songs.isEmpty
          ? const Center(child: Text('Sync your library to see matching songs'))
          : ListView.builder(
              itemCount: songs.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${songs.length} songs • ${formatTotal(total)}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: songs.isEmpty
                                    ? null
                                    : () => player.playSongs(songs,
                                        source: playlist.title),
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
                                        shuffle: true, source: playlist.title),
                                icon: const Icon(Icons.shuffle),
                                label: const Text('Shuffle'),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Download all',
                              icon: const Icon(Icons.download_outlined),
                              onPressed: songs.isEmpty
                                  ? null
                                  : () => downloads.downloadSongs(songs),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                final index = i - 1;
                return SongTile(
                  song: songs[index],
                  onTap: () => player.playSongs(songs,
                      index: index, source: playlist.title),
                );
              },
            ),
    );
  }
}
