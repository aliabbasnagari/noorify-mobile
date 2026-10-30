import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';

import '../state/settings_controller.dart';
import 'adaptive/window_class.dart';
import 'routing/app_routes.dart';
import 'shell/library_entries.dart';
import 'shell/library_sidebar.dart';
import 'shell/player_bar.dart';
import 'shell/queue_panel.dart';
import 'shell/top_bar.dart';
import 'widgets/create_sheet.dart';
import 'widgets/mini_player.dart';
import 'widgets/playback_shortcuts.dart';

/// The signed-in app frame. It picks its layout from the window size and keeps
/// the same pages, page stacks and playback state when the size changes (a
/// rotation, a window dragged across a breakpoint, a folding device):
///
/// * compact: page, then mini player, then a bottom navigation bar.
/// * medium: a navigation rail beside the page, mini player underneath.
/// * expanded (desktop, web, landscape tablets): a top bar with home and
///   search, a library sidebar, the page in a rounded panel, an optional queue
///   panel on the right and a full player bar along the bottom.
///
/// Compact and medium have four destinations: Home, Search, Your Library and
/// Create (an action that opens the Create menu, not a page). Expanded has
/// none of its own: Home and search are in the top bar and the library is the
/// sidebar, but the same three tabs sit underneath, so resizing keeps the
/// user's place.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.branchKeys,
  });

  /// The tab pages, owned by the router. Each tab keeps its own page stack.
  final StatefulNavigationShell navigationShell;

  /// The navigator of each tab, in tab order, used to close the topmost page
  /// of the current tab on a system back gesture.
  final List<GlobalKey<NavigatorState>> branchKeys;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _createIndex = 3;

  int get _index => widget.navigationShell.currentIndex;

  @override
  void initState() {
    super.initState();
    unawaited(_requestNotificationPermission());
  }

  /// Android 13+ makes the playback notification opt-in. Asking once after
  /// sign-in is enough: the system won't show the prompt again after it has
  /// been answered, and older Android versions grant it automatically.
  Future<void> _requestNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Permission.notification.request();
    } on Object {
      // Playback works without the notification; never block the app on it.
    }
  }

  /// System back: close the current tab's top page, else return to Home, else
  /// leave the app.
  Future<void> _handleBack() async {
    final tabNavigator = widget.branchKeys[_index].currentState;
    if (tabNavigator != null && await tabNavigator.maybePop()) return;
    if (_index != 0) {
      widget.navigationShell.goBranch(0);
    } else {
      await SystemNavigator.pop();
    }
  }

  void _select(int destination) {
    if (destination == _createIndex) {
      unawaited(showCreateSheet(context, branchIndex: _index));
      return;
    }
    widget.navigationShell.goBranch(
      destination,
      // Tapping the tab you are already on returns it to its first page.
      initialLocation: destination == _index,
    );
  }

  void _openSettings() =>
      context.push(AppRoutes.branchPath(_index, 'settings'));

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.of(context);
    // The tab pages survive moving between layouts because each tab's
    // Navigator is held under its own GlobalKey (the router's branch keys), so
    // the same widget can simply be placed in a different parent.
    final content = widget.navigationShell;

    return PlaybackShortcuts(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_handleBack());
        },
        child: switch (window) {
          WindowClass.compact => _compact(content),
          WindowClass.medium => _medium(content),
          WindowClass.expanded => _expanded(content),
        },
      ),
    );
  }

  Widget _compact(Widget content) => Scaffold(
        body: content,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music),
                  label: 'Your Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add),
                  label: 'Create',
                ),
              ],
            ),
          ],
        ),
      );

  Widget _medium(Widget content) => Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: IconButton(
                            tooltip: 'Settings',
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: _openSettings,
                          ),
                        ),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search),
                        label: Text('Search'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music),
                        label: Text('Your Library'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.add),
                        label: Text('Create'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: content),
                ],
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      );

  /// A sidebar entry was chosen: browse to it from Home, replacing whatever
  /// page was open there (the sidebar is navigation, not a drill-down).
  void _openEntry(LibraryEntry entry) =>
      context.go(AppRoutes.branchPath(0, entry.detailPath));

  Widget _expanded(Widget content) {
    final shell = context.watch<SettingsController>().shell;
    final windowWidth = MediaQuery.sizeOf(context).width;
    final sidebarWidth = shell.sidebarCollapsed
        ? LibrarySidebar.collapsedWidth
        : LibrarySidebar.expandedWidth(windowWidth);

    return Scaffold(
      body: Column(
        children: [
          AppTopBar(navigationShell: widget.navigationShell),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: sidebarWidth,
                    child: _Panel(
                      child: LibrarySidebar(
                        branchIndex: _index,
                        onOpen: _openEntry,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _Panel(inset: true, child: content)),
                  if (shell.queuePanelOpen) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 340,
                      child: _Panel(
                        child: QueuePanel(
                          onFindSomething: () => widget.navigationShell
                              .goBranch(1, initialLocation: true),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const PlayerBar(),
        ],
      ),
    );
  }
}

/// A rounded surface that frames one column of the expanded layout.
///
/// With [inset] the pages shown inside take the panel's colour for their own
/// background and app bar, instead of painting the page colour over it.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.inset = false});

  final Widget child;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = inset
        ? Theme(
            data: theme.copyWith(
              scaffoldBackgroundColor: scheme.surfaceContainer,
              appBarTheme: theme.appBarTheme.copyWith(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
              ),
            ),
            child: child,
          )
        : child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(color: scheme.surfaceContainer, child: body),
    );
  }
}
