import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../settings/settings_models.dart';
import '../../state/download_controller.dart';
import '../../state/library_data.dart';
import '../../state/library_recents.dart';
import '../../state/settings_controller.dart';
import '../../state/smart_playlist_store.dart';
import '../shell/library_entries.dart';
import '../adaptive/platform_caps.dart';
import 'cover_art.dart';

/// The rows Your Library should show right now, rebuilding the caller when any
/// of the data behind them changes (server lists, smart playlists, recents,
/// offline collections, sort order).
List<LibraryEntry> watchLibraryEntries(
  BuildContext context, {
  LibraryFilter? filter,
  String query = '',
}) {
  final data = context.watch<LibraryData>();
  final layout = context.watch<SettingsController>().shell;
  final smart = context.watch<SmartPlaylistStore>().items;
  final recents = context.watch<LibraryRecents>().all;
  final offline = {
    for (final c in context.watch<DownloadController>().collections) c.key,
  };
  final downloads = context.watch<PlatformCaps>().supportsDownloads;

  return visibleLibraryEntries(
    buildLibraryEntries(
      includeDownloads: downloads,
      playlists: data.playlists ?? const [],
      smartPlaylists: smart,
      artists: data.artists ?? const [],
      albums: data.albums ?? const [],
    ),
    filter: filter,
    query: query,
    sort: layout.librarySort,
    opened: recents,
    offlineKeys: offline,
  );
}

/// Your Library as a browsable list: filter chips, an in-list search, sorting
/// (Recents or A to Z) and a list, compact or grid view, over everything in
/// the library. The phone's Library page and the desktop sidebar both show it;
/// the data comes from [LibraryData] and the sort and view are remembered in
/// [ShellLayoutSettings].
class LibraryBrowser extends StatefulWidget {
  const LibraryBrowser({super.key, required this.onOpen, this.selectedKey});

  /// Called when a row is chosen.
  final void Function(LibraryEntry entry) onOpen;

  /// The [LibraryEntry.key] of the row to highlight as the one open now.
  final String? selectedKey;

  @override
  State<LibraryBrowser> createState() => _LibraryBrowserState();
}

class _LibraryBrowserState extends State<LibraryBrowser> {
  final _search = TextEditingController();
  LibraryFilter? _filter;
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final layout = settings.shell;
    final data = context.watch<LibraryData>();
    final visible =
        watchLibraryEntries(context, filter: _filter, query: _search.text);

    void update(ShellLayoutSettings Function(ShellLayoutSettings) change) =>
        settings.updateShell(change);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (data.someFailed)
          _LoadNote(hadAnyData: data.hasAnyData, onRetry: data.refresh),
        Expanded(
          child: data.isLoading && !data.hasAnyData && visible.length <= 4
              ? const Center(child: CircularProgressIndicator())
              : visible.isEmpty
                  ? const _NothingFound()
                  : _EntryList(
                      entries: visible,
                      view: layout.libraryView,
                      selectedKey: widget.selectedKey,
                      onOpen: widget.onOpen,
                    ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final LibraryFilter? selected;
  final ValueChanged<LibraryFilter?> onSelected;

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<PlatformCaps>().supportsDownloads;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final f in LibraryFilter.values)
            if (downloads || f != LibraryFilter.downloaded)
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
    this.selectedKey,
  });

  final List<LibraryEntry> entries;
  final LibraryViewMode view;
  final void Function(LibraryEntry entry) onOpen;
  final String? selectedKey;

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
            child: SelectedFrame(
              selected: entries[i].key == selectedKey,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onOpen(entries[i]),
                child: LibraryEntryArt(entry: entries[i], size: null),
              ),
            ),
          ),
        );
      case LibraryViewMode.compact:
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (_, i) => ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: LibraryEntryArt(entry: entries[i], size: 32),
            selected: entries[i].key == selectedKey,
            title: Text(entries[i].title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => onOpen(entries[i]),
          ),
        );
      case LibraryViewMode.list:
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (_, i) => ListTile(
            leading: LibraryEntryArt(entry: entries[i], size: 48),
            selected: entries[i].key == selectedKey,
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

/// Outlines a tile that is the item open now, and leaves an equal transparent
/// border otherwise so tiles do not shift when the selection changes.
class SelectedFrame extends StatelessWidget {
  const SelectedFrame({super.key, required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: 2,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(2), child: child),
      );
}

/// Cover art for a library row: a heart tile for Favorites, an icon tile for
/// the shortcuts and smart playlists, a circle for artists, and the server's
/// cover art for the rest. A null [size] fills the space it is given.
class LibraryEntryArt extends StatelessWidget {
  const LibraryEntryArt({super.key, required this.entry, required this.size});

  final LibraryEntry entry;
  final double? size;

  static IconData _shortcutIcon(String id) => switch (id) {
        LibraryEntry.shortcutSongs => Icons.music_note,
        LibraryEntry.shortcutDownloads => Icons.download_done,
        _ => Icons.auto_awesome,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget iconTile(IconData icon) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: scheme.secondaryContainer,
          ),
          child: Center(child: Icon(icon, color: scheme.onSurfaceVariant)),
        );

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
      case LibraryKind.shortcut:
        art = iconTile(_shortcutIcon(entry.id));
      case LibraryKind.smartPlaylist:
        art = iconTile(Icons.auto_awesome);
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
