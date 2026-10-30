import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/playlists_revision.dart';
import '../../state/session_controller.dart';
import '../routing/app_routes.dart';
import 'song_tile.dart' show promptForText;

/// The "Create" menu: a bottom sheet of titled options. Playlist creates an
/// empty server playlist and shows it in Your Library; Smart playlist opens
/// the rule editor inside the tab at [branchIndex].
Future<void> showCreateSheet(BuildContext context,
    {required int branchIndex}) async {
  final action = await showModalBottomSheet<_CreateAction>(
    context: context,
    // Opens a dialog afterwards; keep sheet and dialog on one Navigator.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CreateOption(
            icon: Icons.music_note_outlined,
            title: 'Playlist',
            subtitle: 'Create a playlist with songs',
            onTap: () => Navigator.pop(sheetContext, _CreateAction.playlist),
          ),
          _CreateOption(
            icon: Icons.auto_awesome_outlined,
            title: 'Smart playlist',
            subtitle: 'Fill a playlist from rules, like genre or year',
            onTap: () =>
                Navigator.pop(sheetContext, _CreateAction.smartPlaylist),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _CreateAction.smartPlaylist:
      await context.push<void>(AppRoutes.branchPath(branchIndex, 'smart/new'));
    case _CreateAction.playlist:
      await _createPlaylist(context);
  }
}

enum _CreateAction { playlist, smartPlaylist }

Future<void> _createPlaylist(BuildContext context) async {
  final client = context.read<SessionController>().client;
  final revision = context.read<PlaylistsRevision>();
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (client == null) return;

  final name = await promptForText(context, 'New playlist', 'Name');
  if (name == null) return;
  try {
    await client.createPlaylist(name);
    revision.bump();
    router.go(AppRoutes.library);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Created "$name"')));
  } on Object catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$e')));
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSurface,
        child: Icon(icon),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
