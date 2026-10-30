import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/session_controller.dart';
import '../util.dart';
import '../widgets/cover_art.dart';
import 'artist_page.dart';

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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => ArtistPage(artistId: a.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
