import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/download_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/cover_art.dart';
import 'settings_page.dart' show formatBytes;

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadController>();
    final player = context.read<PlayerController>();
    final songs = downloads.downloaded;
    final collections = downloads.collections;
    final failures = downloads.failures;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          if (songs.isNotEmpty || collections.isNotEmpty)
            IconButton(
              tooltip: 'Remove all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove all downloads?'),
                    content: const Text(
                        'Downloaded files and offline collections will be deleted.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remove')),
                    ],
                  ),
                );
                if (ok == true) await downloads.clearAll();
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(
                '${songs.length} songs • ${formatBytes(downloads.usedBytes)}'),
            subtitle: downloads.activeCount > 0
                ? Text('${downloads.activeCount} in progress')
                : null,
          ),
          if (failures.isNotEmpty)
            ListTile(
              leading: Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('${failures.length} downloads failed'),
              subtitle: Text(failures.values.first),
            ),
          if (collections.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Offline collections'),
            ),
            for (final c in collections)
              ListTile(
                leading:
                    Icon(c.type == 'album' ? Icons.album : Icons.queue_music),
                title: Text(c.title),
                subtitle: Text(c.type == 'album' ? 'Album' : 'Playlist'),
                trailing: IconButton(
                  tooltip: 'Stop keeping offline',
                  icon: const Icon(Icons.cloud_off_outlined),
                  onPressed: () => downloads.removeCollection(c.key),
                ),
              ),
          ],
          if (songs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Songs'),
            ),
            for (var i = 0; i < songs.length; i++)
              ListTile(
                leading: CoverArt(
                    coverArt: songs[i].song.coverArt,
                    size: 44,
                    requestSize: 100,
                    radius: 6),
                title: Text(songs[i].song.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${songs[i].song.artist ?? ''} • ${formatBytes(songs[i].bytes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => downloads.removeSong(songs[i].song.id),
                ),
                onTap: () => player.playSongs([for (final d in songs) d.song],
                    index: i, source: 'Downloads'),
              ),
          ],
          if (songs.isEmpty && collections.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nothing downloaded yet. Use "Download" on a song, or '
                  '"Available offline" on an album or playlist.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
