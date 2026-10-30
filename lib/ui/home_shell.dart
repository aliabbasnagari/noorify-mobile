import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/home_tab.dart';
import 'pages/library_tab.dart';
import 'pages/search_tab.dart';
import 'widgets/mini_player.dart';

/// Spotify's own mobile nav is exactly these three tabs — everything else
/// (Albums/Artists/Songs/Playlists/Smart Playlists/Downloads) lives inside
/// the Library tab's "Your Library" hub instead of its own bottom-bar slot.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    HomeTab(),
    SearchTab(),
    LibraryTab(),
  ];

  /// One `Navigator` per tab, so pushing a page (album, artist, settings,
  /// ...) from inside a tab only replaces that tab's content — the
  /// MiniPlayer/NavigationBar below live outside all of these and stay on
  /// screen, matching Spotify rather than hiding behind every pushed page.
  late final _navigatorKeys =
      List.generate(_tabs.length, (_) => GlobalKey<NavigatorState>());

  Widget _tabNavigator(int index) => Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _tabs[index],
        ),
      );

  Future<void> _handleBack() async {
    final tabNavigator = _navigatorKeys[_index].currentState;
    if (tabNavigator != null && tabNavigator.canPop()) {
      tabNavigator.pop();
    } else if (_index != 0) {
      setState(() => _index = 0);
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [for (var i = 0; i < _tabs.length; i++) _tabNavigator(i)],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                    icon: Icon(Icons.search), label: 'Search'),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music),
                  label: 'Your Library',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
