import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/download_controller.dart';

/// "Available offline" toggle for an album or playlist. While on, the
/// collection is kept in sync with the server (new songs download
/// automatically).
class OfflineSwitch extends StatelessWidget {
  const OfflineSwitch(
      {super.key, required this.collection, required this.songs});

  final OfflineCollection collection;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final offline = context.select<DownloadController, bool>(
      (d) => d.isCollectionOffline(collection.type, collection.id),
    );
    final downloads = context.read<DownloadController>();
    return SwitchListTile(
      secondary: Icon(offline ? Icons.download_done : Icons.download_outlined),
      title: const Text('Available offline'),
      value: offline,
      onChanged: songs.isEmpty
          ? null
          : (on) => on
              ? downloads.setCollectionOffline(collection, songs)
              : downloads.removeCollection(collection.key),
    );
  }
}
