import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/session_controller.dart';
import '../adaptive/layout.dart';
import '../adaptive/window_class.dart';
import '../util.dart';
import '../widgets/cover_art.dart';
import '../routing/navigation.dart';

class ArtistListPage extends StatefulWidget {
  const ArtistListPage({super.key});

  @override
  State<ArtistListPage> createState() => _ArtistListPageState();
}

class _ArtistListPageState extends State<ArtistListPage> {
  late Future<List<Artist>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = context.read<SessionController>().client!.getArtists();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artists')),
      body: FutureBuilder<List<Artist>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorRetry(
                error: snap.error!, onRetry: () => setState(_load));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final artists = snap.data!;
          // A phone gets a dense list; wider windows get a grid of round
          // portraits, which uses the space and reads as artists, not albums.
          if (!WindowClass.of(context).isCompact) {
            return ContentFrame(child: _ArtistGrid(artists: artists));
          }
          return ListView.builder(
            itemCount: artists.length,
            itemBuilder: (_, i) {
              final a = artists[i];
              return ListTile(
                leading: ClipOval(
                  child: CoverArt(
                      coverArt: a.coverArt,
                      size: 44,
                      requestSize: 100,
                      radius: 22),
                ),
                title: Text(a.name),
                subtitle: Text('${a.albumCount} albums'),
                onTap: () => context.openArtist(a.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _ArtistGrid extends StatelessWidget {
  const _ArtistGrid({required this.artists});

  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: ArtGridDelegate.of(context, maxTileWidth: 170),
      itemCount: artists.length,
      itemBuilder: (_, i) {
        final a = artists[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.openArtist(a.id),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipOval(child: CoverArt(coverArt: a.coverArt)),
              ),
              const SizedBox(height: 6),
              Text(
                a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall,
              ),
              Text(
                '${a.albumCount} albums',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
