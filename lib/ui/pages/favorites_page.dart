import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/session_controller.dart';
import '../../state/star_controller.dart';
import '../util.dart';
import '../widgets/collection_page.dart';
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorRetry(
                error: snap.error!, onRetry: () => setState(_load));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = [
            for (final s in snap.data!)
              if (stars.isStarred(s)) s,
          ];
          final total = songs.fold<int>(0, (sum, s) => sum + s.duration);

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              CollectionHeader(
                type: 'Playlist',
                title: 'Favorites',
                artBuilder: (size) => _HeartArt(size: size),
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
                    : () => player.playSongs(songs, source: 'Favorites'),
                onShuffle: songs.isEmpty
                    ? null
                    : () => player.playSongs(songs,
                        shuffle: true, source: 'Favorites'),
              ),
              if (songs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No favorite songs yet. Use "Add to favorites" on a song '
                    'or the heart on the Now Playing screen.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                const TrackTableHeader(),
                for (var i = 0; i < songs.length; i++)
                  SongTile(
                    song: songs[i],
                    onTap: () =>
                        player.playSongs(songs, index: i, source: 'Favorites'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Favorites' cover: the same purple-to-mint heart as in Your Library.
class _HeartArt extends StatelessWidget {
  const _HeartArt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A2CF0), Color(0xFF8FD9C0)],
            ),
          ),
          child: Icon(Icons.favorite, size: size * 0.4, color: Colors.white),
        ),
      );
}
