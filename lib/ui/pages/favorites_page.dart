import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/session_controller.dart';
import '../../state/star_controller.dart';
import '../util.dart';
import '../widgets/song_tile.dart';

/// The user's starred songs, from the server's `getStarred2`. Songs unstarred
/// while this page is open drop out of the list immediately.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<Song>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = context.read<SessionController>().client!.getStarredSongs();

  @override
  Widget build(BuildContext context) {
    final stars = context.watch<StarController>();
    final player = context.read<PlayerController>();
    return FutureBuilder<List<Song>>(
      future: _future,
      builder: (context, snap) {
        final songs = [
          for (final s in snap.data ?? const <Song>[])
            if (stars.isStarred(s)) s,
        ];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Favorites'),
            actions: [
              if (songs.isNotEmpty)
                IconButton(
                  tooltip: 'Shuffle all',
                  icon: const Icon(Icons.shuffle),
                  onPressed: () => player.playSongs(songs,
                      shuffle: true, source: 'Favorites'),
                ),
            ],
          ),
          body: Builder(builder: (context) {
            if (snap.hasError) {
              return ErrorRetry(
                  error: snap.error!, onRetry: () => setState(_load));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (songs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No favorite songs yet. Use "Add to favorites" on a song '
                    'or the heart on the Now Playing screen.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: songs.length,
              itemBuilder: (_, i) => SongTile(
                song: songs[i],
                onTap: () =>
                    player.playSongs(songs, index: i, source: 'Favorites'),
              ),
            );
          }),
        );
      },
    );
  }
}
