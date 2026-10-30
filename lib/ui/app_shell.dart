import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'adaptive/window_class.dart';
import 'routing/app_routes.dart';
import 'widgets/create_sheet.dart';
import 'widgets/mini_player.dart';
import 'widgets/playback_shortcuts.dart';

/// The signed-in app frame. It picks its layout from the window size and keeps
/// the same pages, page stacks and playback state when the size changes (a
/// rotation, a window dragged across a breakpoint, a folding device):
///
/// * compact: page, then mini player, then a bottom navigation bar.
/// * medium: a navigation rail beside the page, mini player underneath.
/// * expanded: as medium with the rail extended to show labels. The top bar,
///   library sidebar, queue panel and player bar of the desktop layout build
///   on this.
///
/// The destinations are Home, Search, Your Library and Create. Create is an
/// action (it opens the Create menu), not a page.
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

  void _openSettings() => context.push(AppRoutes.branchPath(_index, 'settings'));

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
        child: window.isCompact
            ? _compact(content)
            : _wide(content, extended: window.isExpanded),
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

  Widget _wide(Widget content, {required bool extended}) => Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    extended: extended,
                    labelType: extended
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
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
}
