import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../settings/settings_models.dart';
import '../../state/download_controller.dart';
import '../../state/library_recents.dart';
import '../../state/playlists_revision.dart';
import '../../state/session_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/smart_playlist_store.dart';
import '../../subsonic/subsonic_client.dart';
import '../widgets/cover_art.dart';
import '../widgets/create_sheet.dart';
import 'library_entries.dart';

/// The wide layout's "Your Library" column: Favorites, playlists, smart
/// playlists, artists and albums in one list, with filter chips, an in-list
/// search, sorting (Recents or A to Z) and list, compact or grid views. It can
/// collapse to a strip of cover art.
///
/// Server data loads once and again whenever a playlist is created elsewhere.
/// If the server can't be reached the sidebar still shows Favorites and smart
/// playlists, with a note and a retry button.
class LibrarySidebar extends StatefulWidget {
  const LibrarySidebar({
    super.key,
    required this.branchIndex,
    required this.onOpen,
  });

  /// The tab a new smart playlist's editor opens in.
  final int branchIndex;

  /// Called when a row is chosen.
  final void Function(LibraryEntry entry) onOpen;

  static const collapsedWidth = 72.0;

  /// The width of the expanded sidebar for a window [windowWidth] wide.
  static double expandedWidth(double windowWidth) =>
      (windowWidth * 0.24).clamp(280.0, 380.0);

  @override
  State<LibrarySidebar> createState() => _LibrarySidebarState();
}

class _LibrarySidebarState extends State<LibrarySidebar> {
  /// The most albums the sidebar loads (one request, A to Z).
  static const _albumLimit = 500;

  late final PlaylistsRevision _revision;
  final _search = TextEditingController();

  List<Playlist>? _playlists;
  List<Artist>? _artists;
  List<Album>? _albums;
  bool _loading = true;
  bool _someFailed = false;
  int _generation = 0;

  LibraryFilter? _filter;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _revision = context.read<PlaylistsRevision>()..addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _revision.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  /// Fetches each source on its own, so one failing (or being offline) still
  /// leaves whatever did load.
  Future<void> _load() async {
    final client = context.read<SessionController>().client;
    if (client == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _someFailed = false;
    });

    var failed = false;
    Future<T?> attempt<T>(Future<T> request) => request.then<T?>(
          (v) => v,
          onError: (Object _) {
            failed = true;
            return null;
          },
        );

    final results = await Future.wait<Object?>([
      attempt(client.getPlaylists()),
      attempt(client.getArtists()),
      attempt(
          client.getAlbumList(AlbumListType.alphabetical, size: _albumLimit)),
    ]);
    if (!mounted || generation != _generation) return;
    setState(() {
      _playlists = (results[0] as List<Playlist>?) ?? _playlists;
      _artists = (results[1] as List<Artist>?) ?? _artists;
      _albums = (results[2] as List<Album>?) ?? _albums;
      _someFailed = failed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final layout = settings.shell;
    final smart = context.watch<SmartPlaylistStore>().items;
    final recents = context.watch<LibraryRecents>().all;
    final offline = {
      for (final c in context.watch<DownloadController>().collections) c.key,
    };

    final entries = buildLibraryEntries(
      playlists: _playlists ?? const [],
      smartPlaylists: smart,
      artists: _artists ?? const [],
      albums: _albums ?? const [],
    );
    final visible = visibleLibraryEntries(
      entries,
      filter: _filter,
      query: _search.text,
      sort: layout.librarySort,
      opened: recents,
      offlineKeys: offline,
    );

    void update(ShellLayoutSettings Function(ShellLayoutSettings) change) =>
        settings.updateShell(change);

    if (layout.sidebarCollapsed) {
      return _Collapsed(
        entries: visible,
        branchIndex: widget.branchIndex,
        onOpen: widget.onOpen,
        onExpand: () => update((s) => s.copyWith(sidebarCollapsed: false)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          branchIndex: widget.branchIndex,
          onCollapse: () => update((s) => s.copyWith(sidebarCollapsed: true)),
        ),
        _FilterChips(
          selected: _filter,
          onSelected: (f) => setState(() => _filter = f),
        ),
        _Toolbar(
          searching: _searching,
          search: _search,
          layout: layout,
          onToggleSearch: () => setState(() {
            _searching = !_searching;
            if (!_searching) _search.clear();
          }),
          onChanged: () => setState(() {}),
          onSort: (sort) => update((s) => s.copyWith(librarySort: sort)),
          onView: (view) => update((s) => s.copyWith(libraryView: view)),
        ),
        if (_someFailed)
          _LoadNote(
            hadAnyData:
                _playlists != null || _artists != null || _albums != null,
            onRetry: _load,
          ),
        Expanded(
          child: _loading && entries.length <= 1
              ? const Center(child: CircularProgressIndicator())
              : visible.isEmpty
                  ? const _NothingFound()
                  : _EntryList(
                      entries: visible,
                      view: layout.libraryView,
                      onOpen: widget.onOpen,
                    ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.branchIndex, required this.onCollapse});

  final int branchIndex;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
        child: Row(
          children: [
            const Icon(Icons.library_music_outlined, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your Library',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            CreateMenuButton(branchIndex: branchIndex),
            IconButton(
              tooltip: 'Collapse your library',
              icon: const Icon(Icons.keyboard_double_arrow_left),
              onPressed: onCollapse,
            ),
          ],
        ),
      );
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final LibraryFilter? selected;
  final ValueChanged<LibraryFilter?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final f in LibraryFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f.label),
                  selected: selected == f,
                  // Choosing the selected chip again clears the filter.
                  onSelected: (on) => onSelected(on ? f : null),
                ),
              ),
          ],
        ),
      );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searching,
    required this.search,
    required this.layout,
    required this.onToggleSearch,
    required this.onChanged,
    required this.onSort,
    required this.onView,
  });

  final bool searching;
  final TextEditingController search;
  final ShellLayoutSettings layout;
  final VoidCallback onToggleSearch;
  final VoidCallback onChanged;
  final ValueChanged<LibrarySort> onSort;
  final ValueChanged<LibraryViewMode> onView;

  static String _sortLabel(LibrarySort sort) => switch (sort) {
        LibrarySort.recents => 'Recents',
        LibrarySort.alphabetical => 'Alphabetical',
      };

  static String _viewLabel(LibraryViewMode mode) => switch (mode) {
        LibraryViewMode.list => 'List',
        LibraryViewMode.compact => 'Compact',
        LibraryViewMode.grid => 'Grid',
      };

  static IconData _viewIcon(LibraryViewMode mode) => switch (mode) {
        LibraryViewMode.list => Icons.view_list,
        LibraryViewMode.compact => Icons.reorder,
        LibraryViewMode.grid => Icons.grid_view,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: searching ? 'Close search' : 'Search in your library',
            icon: Icon(searching ? Icons.close : Icons.search),
            onPressed: onToggleSearch,
          ),
          if (searching)
            Expanded(
              child: TextField(
                controller: search,
                autofocus: true,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  hintText: 'Search in your library',
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
            )
          else
            const Spacer(),
          PopupMenuButton<LibrarySort>(
            tooltip: 'Sort',
            initialValue: layout.librarySort,
            onSelected: onSort,
            itemBuilder: (_) => [
              for (final s in LibrarySort.values)
                PopupMenuItem(value: s, child: Text(_sortLabel(s))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(_sortLabel(layout.librarySort),
                  style: textTheme.labelLarge),
            ),
          ),
          PopupMenuButton<LibraryViewMode>(
            tooltip: 'View as',
            initialValue: layout.libraryView,
            onSelected: onView,
            icon: Icon(_viewIcon(layout.libraryView)),
            itemBuilder: (_) => [
              for (final m in LibraryViewMode.values)
                PopupMenuItem(
                  value: m,
                  child: Row(
                    children: [
                      Icon(_viewIcon(m), size: 20),
                      const SizedBox(width: 12),
                      Text(_viewLabel(m)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadNote extends StatelessWidget {
  const _LoadNote({required this.hadAnyData, required this.onRetry});

  final bool hadAnyData;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hadAnyData
                    ? 'Some of your library could not be loaded.'
                    : "Couldn't reach your server.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _NothingFound extends StatelessWidget {
  const _NothingFound();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'Nothing here',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.entries,
    required this.view,
    required this.onOpen,
  });

  final List<LibraryEntry> entries;
  final LibraryViewMode view;
  final void Function(LibraryEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    switch (view) {
      case LibraryViewMode.grid:
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 104,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: entries.length,
          itemBuilder: (_, i) => Tooltip(
            message: entries[i].title,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onOpen(entries[i]),
              child: _EntryArt(entry: entries[i], size: null),
            ),
          ),
        );
      case LibraryViewMode.compact:
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (_, i) => ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: _EntryArt(entry: entries[i], size: 32),
            title: Text(entries[i].title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => onOpen(entries[i]),
          ),
        );
      case LibraryViewMode.list:
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (_, i) => ListTile(
            leading: _EntryArt(entry: entries[i], size: 48),
            title: Text(entries[i].title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(entries[i].subtitle,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => onOpen(entries[i]),
          ),
        );
    }
  }
}

/// The strip shown when the sidebar is collapsed: just cover art with a
/// tooltip, plus the buttons to expand and to create.
class _Collapsed extends StatelessWidget {
  const _Collapsed({
    required this.entries,
    required this.branchIndex,
    required this.onOpen,
    required this.onExpand,
  });

  final List<LibraryEntry> entries;
  final int branchIndex;
  final void Function(LibraryEntry entry) onOpen;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const SizedBox(height: 8),
          IconButton(
            tooltip: 'Expand your library',
            icon: const Icon(Icons.library_music_outlined),
            onPressed: onExpand,
          ),
          CreateMenuButton(branchIndex: branchIndex),
          const Divider(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (_, i) => Tooltip(
                message: entries[i].title,
                child: InkWell(
                  onTap: () => onOpen(entries[i]),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: _EntryArt(entry: entries[i], size: 48),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

/// Cover art for a row: a heart tile for Favorites, a circle for artists, an
/// icon tile for smart playlists, and the server's cover art for the rest.
/// A null [size] fills the space it is given (the grid).
class _EntryArt extends StatelessWidget {
  const _EntryArt({required this.entry, required this.size});

  final LibraryEntry entry;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget art;
    switch (entry.kind) {
      case LibraryKind.favorites:
        art = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A2CF0), Color(0xFF8FD9C0)],
            ),
          ),
          child: const Center(child: Icon(Icons.favorite, color: Colors.white)),
        );
      case LibraryKind.smartPlaylist:
        art = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: scheme.secondaryContainer,
          ),
          child: Center(
            child: Icon(Icons.auto_awesome, color: scheme.onSurfaceVariant),
          ),
        );
      case LibraryKind.artist:
        art = ClipOval(
          child: CoverArt(
              coverArt: entry.coverArt,
              size: size,
              requestSize: 100,
              radius: 0),
        );
      case LibraryKind.playlist:
      case LibraryKind.album:
        art = CoverArt(
            coverArt: entry.coverArt, size: size, requestSize: 100, radius: 4);
    }

    if (size == null) return AspectRatio(aspectRatio: 1, child: art);
    return SizedBox(width: size, height: size, child: art);
  }
}
