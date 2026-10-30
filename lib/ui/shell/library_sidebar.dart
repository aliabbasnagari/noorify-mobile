import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../settings/settings_models.dart';
import '../../state/settings_controller.dart';
import '../widgets/create_sheet.dart';
import '../widgets/library_browser.dart';
import 'library_entries.dart';

/// The wide layout's "Your Library" column: a header with the Create menu and
/// a collapse button over the shared [LibraryBrowser]. Collapsed, it shrinks to
/// a strip of cover art.
class LibrarySidebar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    void update(ShellLayoutSettings Function(ShellLayoutSettings) change) =>
        settings.updateShell(change);

    if (settings.shell.sidebarCollapsed) {
      return _Collapsed(
        branchIndex: branchIndex,
        onOpen: onOpen,
        onExpand: () => update((s) => s.copyWith(sidebarCollapsed: false)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
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
                onPressed: () =>
                    update((s) => s.copyWith(sidebarCollapsed: true)),
              ),
            ],
          ),
        ),
        Expanded(child: LibraryBrowser(onOpen: onOpen)),
      ],
    );
  }
}

/// The strip shown when the sidebar is collapsed: just cover art with a
/// tooltip, plus the buttons to expand and to create.
class _Collapsed extends StatelessWidget {
  const _Collapsed({
    required this.branchIndex,
    required this.onOpen,
    required this.onExpand,
  });

  final int branchIndex;
  final void Function(LibraryEntry entry) onOpen;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final entries = watchLibraryEntries(context);
    return Column(
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
                  child: LibraryEntryArt(entry: entries[i], size: 48),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
