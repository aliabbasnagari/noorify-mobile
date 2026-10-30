import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../smart/smart_filter.dart';
import '../../state/smart_playlist_store.dart';
import '../../state/sync_controller.dart';
import '../routing/navigation.dart';

/// "Smart" tab: rule-based playlists evaluated against the synced library.
class SmartPlaylistsView extends StatelessWidget {
  const SmartPlaylistsView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SmartPlaylistStore>();
    final sync = context.watch<SyncController>();
    final items = store.items;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'New smart playlist',
        onPressed: () => context.openNewSmartPlaylist(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          if (sync.songs.isEmpty)
            Card(
              margin: const EdgeInsets.all(16),
              child: ListTile(
                leading: sync.isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                title: const Text('Sync your library first'),
                subtitle: Text(
                  sync.isSyncing
                      ? '${sync.songs.length} songs so far…'
                      : (sync.error != null
                          ? 'Sync failed: ${sync.error}'
                          : 'Smart playlists run against a local copy of your song list.'),
                ),
                trailing: sync.isSyncing
                    ? null
                    : FilledButton.tonal(
                        onPressed: sync.sync, child: const Text('Sync')),
              ),
            ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No smart playlists yet. Create one from rules like '
                  '"Genre contains jazz" and "Added in the last 30 days".',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          for (final p in items) _Tile(playlist: p),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.playlist});

  final SmartPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final rules = playlist.filter.rules.length;
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.auto_awesome)),
      title: Text(playlist.title),
      subtitle: Text('$rules ${rules == 1 ? 'rule' : 'rules'}'),
      onTap: () => context.openSmartPlaylist(playlist.id),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') {
            context.editSmartPlaylist(playlist.id);
          } else if (v == 'delete') {
            context.read<SmartPlaylistStore>().remove(playlist.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
