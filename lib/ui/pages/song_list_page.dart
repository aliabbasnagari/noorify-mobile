import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/sync_controller.dart';
import '../adaptive/layout.dart';
import '../util.dart';
import 'song_sort.dart';
import '../widgets/song_tile.dart';

/// Flat list of every song, backed by [SyncController]'s library cache
/// (the same local database smart playlists are evaluated against), ordered by
/// the chosen column.
class SongListPage extends StatefulWidget {
  const SongListPage({super.key});

  @override
  State<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends State<SongListPage> {
  SongSort _sort = SongSort.title;
  bool _ascending = true;

  // Sorting thousands of songs on every rebuild would be wasteful, so the
  // result is kept until the songs or the order change.
  List<Song>? _source;
  SongSort? _sortedBy;
  bool? _sortedAscending;
  List<Song> _sorted = const [];

  List<Song> _ordered(List<Song> songs) {
    if (!identical(songs, _source) ||
        _sortedBy != _sort ||
        _sortedAscending != _ascending) {
      _source = songs;
      _sortedBy = _sort;
      _sortedAscending = _ascending;
      _sorted = sortSongs(songs, _sort, ascending: _ascending);
    }
    return _sorted;
  }

  /// Choosing the current column again flips its direction.
  void _choose(SongSort sort) => setState(() {
        if (sort == _sort) {
          _ascending = !_ascending;
        } else {
          _sort = sort;
          _ascending = true;
        }
      });

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final player = context.read<PlayerController>();
    final songs = sync.songs.isEmpty ? sync.songs : _ordered(sync.songs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Songs'),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              tooltip: 'Shuffle all',
              icon: const Icon(Icons.shuffle),
              onPressed: () =>
                  player.playSongs(songs, shuffle: true, source: 'Songs'),
            ),
        ],
      ),
      body: songs.isEmpty
          ? _EmptyState(sync: sync)
          : ContentFrame(
              child: Column(
                children: [
                  _SortBar(
                    sort: _sort,
                    ascending: _ascending,
                    onChoose: _choose,
                  ),
                  Expanded(child: _SongList(songs: songs, player: player)),
                ],
              ),
            ),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sort,
    required this.ascending,
    required this.onChoose,
  });

  final SongSort sort;
  final bool ascending;
  final ValueChanged<SongSort> onChoose;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            for (final s in SongSort.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.label),
                  selected: s == sort,
                  avatar: s == sort
                      ? Icon(
                          ascending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16,
                          semanticLabel: ascending ? 'Ascending' : 'Descending',
                        )
                      : null,
                  showCheckmark: false,
                  onSelected: (_) => onChoose(s),
                ),
              ),
          ],
        ),
      );
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
          onTap: () => player.playSongs(songs, index: i, source: 'Songs'),
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
