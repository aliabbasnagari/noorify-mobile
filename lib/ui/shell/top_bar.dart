import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/search_query.dart';
import '../../state/session_controller.dart';
import '../../state/sync_controller.dart';
import '../account/sign_out.dart';
import '../routing/app_routes.dart';

/// The wide layout's top bar: the app mark, a home button beside a wide search
/// field, and the account menu.
///
/// Typing in the field updates the shared [SearchQuery] and switches to the
/// Search tab, whose page shows the results. The field and the query stay in
/// step if the query is changed from elsewhere.
class AppTopBar extends StatefulWidget {
  const AppTopBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  static const _searchBranch = 1;

  final _controller = TextEditingController();
  late final SearchQuery _query;

  @override
  void initState() {
    super.initState();
    _query = context.read<SearchQuery>()..addListener(_syncFromQuery);
    _controller.text = _query.text;
  }

  @override
  void dispose() {
    _query.removeListener(_syncFromQuery);
    _controller.dispose();
    super.dispose();
  }

  void _syncFromQuery() {
    if (_controller.text == _query.text) return;
    _controller.value = TextEditingValue(
      text: _query.text,
      selection: TextSelection.collapsed(offset: _query.text.length),
    );
  }

  void _openSearch() {
    if (widget.navigationShell.currentIndex != _searchBranch) {
      widget.navigationShell.goBranch(_searchBranch);
    }
  }

  void _goHome() => widget.navigationShell.goBranch(0, initialLocation: true);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final atHome = widget.navigationShell.currentIndex == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const _AppMark(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Home',
                        icon: Icon(atHome ? Icons.home : Icons.home_outlined),
                        onPressed: _goHome,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: _controller,
                          builder: (context, _) => TextField(
                            controller: _controller,
                            onTap: _openSearch,
                            onChanged: (text) {
                              _query.set(text);
                              if (text.trim().isNotEmpty) _openSearch();
                            },
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'What do you want to listen to?',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _controller.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear',
                                      icon: const Icon(Icons.close),
                                      onPressed: _query.clear,
                                    ),
                              filled: true,
                              fillColor: scheme.surfaceContainerHigh,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _AccountMenu(branchIndex: widget.navigationShell.currentIndex),
          ],
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 48,
        child: Align(
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 32,
              height: 32,
              errorBuilder: (_, __, ___) => Icon(
                Icons.library_music,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
}

enum _AccountAction { settings, sync, signOut }

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.branchIndex});

  final int branchIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final username =
        context.watch<SessionController>().client?.config.username ?? '';
    final sync = context.watch<SyncController>();
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();

    return PopupMenuButton<_AccountAction>(
      tooltip: username.isEmpty ? 'Account' : 'Account: $username',
      offset: const Offset(0, 48),
      onSelected: (action) {
        switch (action) {
          case _AccountAction.settings:
            context.push(AppRoutes.branchPath(branchIndex, 'settings'));
          case _AccountAction.sync:
            context.read<SyncController>().sync();
          case _AccountAction.signOut:
            confirmSignOut(context);
        }
      },
      itemBuilder: (_) => [
        if (username.isNotEmpty)
          PopupMenuItem<_AccountAction>(
            enabled: false,
            child: Text(username),
          ),
        const PopupMenuItem(
          value: _AccountAction.settings,
          child: Text('Settings'),
        ),
        PopupMenuItem(
          value: _AccountAction.sync,
          enabled: !sync.isSyncing,
          child: Text(sync.isSyncing ? 'Syncing library…' : 'Sync library'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountAction.signOut,
          child: Text('Sign out'),
        ),
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child:
            Text(initial, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
