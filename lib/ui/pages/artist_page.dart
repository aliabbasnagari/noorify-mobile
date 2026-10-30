import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/session_controller.dart';
import '../util.dart';
import '../widgets/album_widgets.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.artistId});

  final String artistId;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  late Future<Artist> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = context.read<SessionController>().client!.getArtist(widget.artistId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Artist>(
      future: _future,
      builder: (context, snap) {
        final artist = snap.data;
        return Scaffold(
          appBar: AppBar(title: Text(artist?.name ?? '')),
          body: Builder(
            builder: (context) {
              if (snap.hasError) {
                return ErrorRetry(error: snap.error!, onRetry: () => setState(_load));
              }
              if (artist == null) return const Center(child: CircularProgressIndicator());
              if (artist.albums.isEmpty) return const Center(child: Text('No albums'));
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: artist.albums.length,
                itemBuilder: (_, i) => AlbumCard(album: artist.albums[i]),
              );
            },
          ),
        );
      },
    );
  }
}
