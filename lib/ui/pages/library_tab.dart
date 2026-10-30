import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/playlists_revision.dart';
import '../../state/session_controller.dart';
import '../routing/navigation.dart';
import '../util.dart';
import '../widgets/cover_art.dart';
import '../widgets/song_tile.dart' show promptForText;

/// "Your Library" hub: a grid of section tiles (Albums, Artists, Songs,
/// Downloads, Smart Playlists) followed by the user's server playlists.
/// Replaces the old four-way (Home/Library/Playlists/Search) bottom nav with
/// Spotify's three-tab Home/Search/Library flow — everything that used to be
/// its own tab or its own `Playlists` destination now lives in here.
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Playlist>> _playlistsFuture;
  late final PlaylistsRevision _revision;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    // Playlists can also be created from the Create menu or "add to a new
    // playlist"; reload so this list never shows a stale set.
    _revision = context.read<PlaylistsRevision>()..addListener(_onRevision);
  }

  @override
  void dispose() {
    _revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) setState(_loadPlaylists);
  }

  void _loadPlaylists() => _playlistsFuture =
      context.read<SessionController>().client!.getPlaylists();

  Future<void> _createPlaylist() async {
    final client = context.read<SessionController>().client!;
    final name = await promptForText(context, 'New playlist', 'Name');
    if (name == null) return;
    try {
      await client.createPlaylist(name);
      if (mounted) setState(_loadPlaylists);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your Library')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                _LibraryTile(
                  icon: Icons.album_outlined,
                  label: 'Albums',
                  onTap: () => context.openAlbums(),
                ),
                _LibraryTile(
                  icon: Icons.person_outline,
                  label: 'Artists',
                  onTap: () => context.openArtists(),
                ),
                _LibraryTile(
                  icon: Icons.music_note_outlined,
                  label: 'Songs',
                  onTap: () => context.openSongs(),
                ),
                _LibraryTile(
                  icon: Icons.favorite_border,
                  label: 'Favorites',
                  onTap: () => context.openFavorites(),
                ),
                _LibraryTile(
                  icon: Icons.download_for_offline_outlined,
                  label: 'Downloads',
                  onTap: () => context.openDownloads(),
                ),
                _LibraryTile(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Smart Playlists',
                  onTap: () => context.openSmartPlaylists(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Playlists',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  tooltip: 'New playlist',
                  icon: const Icon(Icons.add),
                  onPressed: _createPlaylist,
                ),
              ],
            ),
          ),
          FutureBuilder<List<Playlist>>(
            future: _playlistsFuture,
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorRetry(
                      error: snap.error!,
                      onRetry: () => setState(_loadPlaylists)),
                );
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final playlists = snap.data!;
              if (playlists.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No playlists yet')),
                );
              }
              return Column(
                children: [
                  for (final p in playlists)
                    ListTile(
                      leading: CoverArt(
                          coverArt: p.coverArt,
                          size: 48,
                          requestSize: 100,
                          radius: 6),
                      title: Text(p.name),
                      subtitle: Text(
                          '${p.songCount} songs • ${formatTotal(p.duration)}'),
                      onTap: () async {
                        await context.openPlaylist(p.id, p.name);
                        if (mounted) setState(_loadPlaylists);
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: scheme.onSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
