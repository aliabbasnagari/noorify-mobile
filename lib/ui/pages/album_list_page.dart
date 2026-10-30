import 'package:flutter/material.dart';

import '../../settings/settings_models.dart';
import '../../subsonic/subsonic_client.dart';
import '../adaptive/layout.dart';
import '../widgets/album_widgets.dart';
import 'home_tab.dart';

/// Every album, A to Z, or the full list behind one of Home's shelves (Newly
/// added, Most played, ...) when opened with a [type].
class AlbumListPage extends StatelessWidget {
  const AlbumListPage({super.key, this.type = AlbumListType.alphabetical});

  final AlbumListType type;

  /// The shelf title for [type], which doubles as this page's title.
  static String titleFor(AlbumListType type) {
    for (final entry in homeRowTypes.entries) {
      if (entry.value == type) return homeRowTitles[entry.key] ?? 'Albums';
    }
    return 'Albums';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titleFor(type))),
        body: ContentFrame(child: PagedAlbumGrid(type: type)),
      );
}
