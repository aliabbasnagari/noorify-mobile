import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/download_controller.dart';
import '../../state/library_recents.dart';
import '../../state/search_query.dart';
import '../../state/session_controller.dart';
import '../../state/sync_controller.dart';
import '../routing/app_routes.dart';

/// Asks for confirmation, then signs out and wipes this account's local data:
/// downloaded files, the synced song cache, the recently-opened history and
/// the search text.
/// Playback stops when the session ends.
Future<void> confirmSignOut(BuildContext context) async {
  final router = GoRouter.of(context);
  final session = context.read<SessionController>();
  final downloads = context.read<DownloadController>();
  final sync = context.read<SyncController>();
  final recents = context.read<LibraryRecents>();
  final search = context.read<SearchQuery>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'Downloaded songs and the synced library will be removed from this '
        'device.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out')),
      ],
    ),
  );
  if (ok != true) return;
  // Wipe while the account's client is still attached, then end the session.
  await downloads.clearAll();
  await sync.clear();
  await recents.clear();
  search.clear();
  await session.logout();
  // Signing out re-runs the router's redirect, which would otherwise send the
  // next sign-in back to the page the user was on.
  router.go(AppRoutes.login);
}
