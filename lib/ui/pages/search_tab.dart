import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/session_controller.dart';
import '../widgets/cover_art.dart';
import '../widgets/song_tile.dart';
import 'album_page.dart';
import 'artist_page.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();
  Timer? _debounce;
  SearchResults? _results;
  Object? _error;
  bool _loading = false;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      _generation++;
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<SessionController>().client!.search(query);
      // Ignore responses that were superseded by a newer query.
      if (!mounted || generation != _generation) return;
      setState(() => _results = results);
    } on Object catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search artists, albums, songs',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return Center(child: Text('$_error'));
    final results = _results;
    if (results == null) return const Center(child: Text('Search your library'));
    if (results.isEmpty) return const Center(child: Text('No results'));

    final player = context.read<PlayerController>();
    return ListView(
      children: [
        if (results.artists.isNotEmpty) const _Header('Artists'),
        for (final a in results.artists)
          ListTile(
            leading: ClipOval(
              child: CoverArt(coverArt: a.coverArt, size: 44, requestSize: 100, radius: 22),
            ),
            title: Text(a.name),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ArtistPage(artistId: a.id)),
            ),
          ),
        if (results.albums.isNotEmpty) const _Header('Albums'),
        for (final a in results.albums)
          ListTile(
            leading: CoverArt(coverArt: a.coverArt, size: 48, requestSize: 100, radius: 6),
            title: Text(a.name),
            subtitle: Text(a.artist ?? ''),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => AlbumPage(albumId: a.id)),
            ),
          ),
        if (results.songs.isNotEmpty) const _Header('Songs'),
        for (var i = 0; i < results.songs.length; i++)
          SongTile(
            song: results.songs[i],
            onTap: () => player.playSongs(results.songs, index: i),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
