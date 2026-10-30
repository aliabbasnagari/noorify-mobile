import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/search_query.dart';
import '../../state/session_controller.dart';
import '../adaptive/window_class.dart';
import '../routing/navigation.dart';
import '../widgets/cover_art.dart';
import '../widgets/song_tile.dart';

/// Search results. The text comes from the shared [SearchQuery]: on phones and
/// tablets this page shows the field itself, on desktop the top bar owns the
/// field and this page just shows what it finds.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();
  late final SearchQuery _query;
  Timer? _debounce;
  SearchResults? _results;
  Object? _error;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _query = context.read<SearchQuery>()..addListener(_onQueryChanged);
    _controller.text = _query.text;
    // Text typed in the top bar before this page existed.
    if (_query.text.trim().isNotEmpty) _search(_query.text.trim());
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// The shared text changed, from this page's field or the top bar's.
  void _onQueryChanged() {
    if (_controller.text != _query.text) {
      _controller.value = TextEditingValue(
        text: _query.text,
        selection: TextSelection.collapsed(offset: _query.text.length),
      );
    }
    _debounce?.cancel();
    final query = _query.text.trim();
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
      final results =
          await context.read<SessionController>().client!.search(query);
      // Ignore responses that were superseded by a newer query.
      if (!mounted || generation != _generation) return;
      setState(() => _results = results);
    } on Object catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Desktop searches from the top bar, so this page has no field of its own.
    final showField = !WindowClass.of(context).isExpanded;

    return Scaffold(
      appBar: showField
          ? AppBar(
              title: TextField(
                controller: _controller,
                onChanged: _query.set,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search artists, albums, songs',
                  border: InputBorder.none,
                ),
              ),
              actions: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear),
                    onPressed: _query.clear,
                  ),
              ],
              bottom: _loading
                  ? const PreferredSize(
                      preferredSize: Size.fromHeight(2),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  : null,
            )
          : null,
      body: Column(
        children: [
          if (!showField && _loading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) return Center(child: Text('$_error'));
    final results = _results;
    if (results == null) {
      return const Center(child: Text('Search your library'));
    }
    if (results.isEmpty) return const Center(child: Text('No results'));

    final player = context.read<PlayerController>();
    return ListView(
      children: [
        if (results.artists.isNotEmpty) const _Header('Artists'),
        for (final a in results.artists)
          ListTile(
            leading: ClipOval(
              child: CoverArt(
                  coverArt: a.coverArt, size: 44, requestSize: 100, radius: 22),
            ),
            title: Text(a.name),
            onTap: () => context.openArtist(a.id),
          ),
        if (results.albums.isNotEmpty) const _Header('Albums'),
        for (final a in results.albums)
          ListTile(
            leading: CoverArt(
                coverArt: a.coverArt, size: 48, requestSize: 100, radius: 6),
            title: Text(a.name),
            subtitle: Text(a.artist ?? ''),
            onTap: () => context.openAlbum(a.id),
          ),
        if (results.songs.isNotEmpty) const _Header('Songs'),
        for (var i = 0; i < results.songs.length; i++)
          SongTile(
            song: results.songs[i],
            onTap: () => player.playSongs(results.songs,
                index: i, source: 'Search results'),
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
