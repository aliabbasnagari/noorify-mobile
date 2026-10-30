import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../settings/settings_models.dart';
import '../../state/settings_controller.dart';
import '../../subsonic/subsonic_client.dart';
import '../widgets/album_widgets.dart';
import '../routing/navigation.dart';

const homeRowTypes = <String, AlbumListType>{
  'recent': AlbumListType.recent,
  'newest': AlbumListType.newest,
  'frequent': AlbumListType.frequent,
  'random': AlbumListType.random,
  'starred': AlbumListType.starred,
};

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = context.watch<SettingsController>().home;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noorify'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.openSettings(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final row in layout.rows)
            if (row.visible && homeRowTypes.containsKey(row.id))
              AlbumShelf(
                // Rebuild (and refetch) when the item count changes.
                key: ValueKey('${row.id}:${row.count}'),
                title: homeRowTitles[row.id]!,
                type: homeRowTypes[row.id]!,
                count: row.count,
              ),
        ],
      ),
    );
  }
}
