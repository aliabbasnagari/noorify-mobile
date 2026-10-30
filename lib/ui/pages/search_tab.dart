import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/search_query.dart';
import '../../state/session_controller.dart';
import '../adaptive/layout.dart';
import '../adaptive/window_class.dart';
import '../routing/navigation.dart';
import '../util.dart';
import '../widgets/cover_art.dart';
import '../widgets/song_tile.dart';
import 'search_top_result.dart';

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
  _Scope _scope = _Scope.all;

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
    final all = _scope == _Scope.all;
    final top = all ? topSearchResult(results, _query.text) : null;

    return ContentFrame(
      maxWidth: 1000,
      child: ListView(
        children: [
          _ScopeChips(
            selected: _scope,
            onSelected: (scope) => setState(() => _scope = scope),
          ),
          if (top != null) _TopResultCard(top: top),
          if (_scope.shows(_Scope.artists) && results.artists.isNotEmpty) ...[
            if (all) const _Header('Artists'),
            for (final a in results.artists)
              ListTile(
                leading: ClipOval(
                  child: CoverArt(
                      coverArt: a.coverArt,
                      size: 44,
                      requestSize: 100,
                      radius: 22),
                ),
                title: Text(a.name),
                subtitle: const Text('Artist'),
                onTap: () => context.openArtist(a.id),
              ),
          ],
          if (_scope.shows(_Scope.albums) && results.albums.isNotEmpty) ...[
            if (all) const _Header('Albums'),
            for (final a in results.albums)
              ListTile(
                leading: CoverArt(
                    coverArt: a.coverArt,
                    size: 48,
                    requestSize: 100,
                    radius: 6),
                title: Text(a.name),
                subtitle: Text(
                    a.artist == null ? 'Album' : 'Album • ${a.artist}'),
                onTap: () => context.openAlbum(a.id),
              ),
          ],
          if (_scope.shows(_Scope.songs) && results.songs.isNotEmpty) ...[
            if (all) const _Header('Songs'),
            for (var i = 0; i < results.songs.length; i++)
              SongTile(
                song: results.songs[i],
                onTap: () => player.playSongs(results.songs,
                    index: i, source: 'Search results'),
              ),
          ],
          // A scope with nothing in it (songs only, but there were none).
          if (!all && _scope.isEmptyIn(results))
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('No ${_scope.label.toLowerCase()}')),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Which kinds of result the Search page shows.
enum _Scope {
  all('All'),
  songs('Songs'),
  albums('Albums'),
  artists('Artists');

  const _Scope(this.label);
  final String label;

  /// Whether this scope includes results of [kind].
  bool shows(_Scope kind) => this == _Scope.all || this == kind;

  bool isEmptyIn(SearchResults r) => switch (this) {
        _Scope.all => r.isEmpty,
        _Scope.songs => r.songs.isEmpty,
        _Scope.albums => r.albums.isEmpty,
        _Scope.artists => r.artists.isEmpty,
      };
}

class _ScopeChips extends StatelessWidget {
  const _ScopeChips({required this.selected, required this.onSelected});

  final _Scope selected;
  final ValueChanged<_Scope> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            for (final scope in _Scope.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(scope.label),
                  selected: selected == scope,
                  onSelected: (_) => onSelected(scope),
                ),
              ),
          ],
        ),
      );
}

/// The best match for the search in a large card: tap it to open, or press
/// play for a song or an album.
class _TopResultCard extends StatelessWidget {
  const _TopResultCard({required this.top});

  final TopResult top;

  String get _type => switch (top.kind) {
        TopResultKind.artist => 'Artist',
        TopResultKind.album => 'Album',
        TopResultKind.song => 'Song',
      };

  String? get _subtitle => switch (top.kind) {
        TopResultKind.artist => null,
        TopResultKind.album => top.album!.artist,
        TopResultKind.song => top.song!.artist,
      };

  String? get _coverArt => switch (top.kind) {
        TopResultKind.artist => top.artist!.coverArt,
        TopResultKind.album => top.album!.coverArt,
        TopResultKind.song => top.song!.coverArt,
      };

  void _open(BuildContext context) {
    switch (top.kind) {
      case TopResultKind.artist:
        context.openArtist(top.artist!.id);
      case TopResultKind.album:
        context.openAlbum(top.album!.id);
      case TopResultKind.song:
        final song = top.song!;
        if (song.albumId != null) {
          context.openAlbum(song.albumId!);
        } else {
          context.read<PlayerController>().playSongs([song],
              source: 'Search results');
        }
    }
  }

  Future<void> _play(BuildContext context) async {
    final player = context.read<PlayerController>();
    switch (top.kind) {
      case TopResultKind.artist:
        context.openArtist(top.artist!.id);
      case TopResultKind.song:
        await player.playSongs([top.song!], source: 'Search results');
      case TopResultKind.album:
        final client = context.read<SessionController>().client!;
        final album = top.album!;
        try {
          final full = await client.getAlbum(album.id);
          await player.playSongs(full.songs, source: album.name);
        } on Object catch (e) {
          if (context.mounted) showError(context, e);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isArtist = top.kind == TopResultKind.artist;
    final art = CoverArt(
      coverArt: _coverArt,
      size: 80,
      requestSize: 200,
      radius: isArtist ? 40 : 6,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                isArtist ? ClipOval(child: art) : art,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        top.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle == null ? _type : '$_type • $_subtitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!isArtist)
                  IconButton.filled(
                    tooltip: 'Play',
                    icon: const Icon(Icons.play_arrow),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                    onPressed: () => _play(context),
                  ),
              ],
            ),
          ),
        ),
      ),
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
