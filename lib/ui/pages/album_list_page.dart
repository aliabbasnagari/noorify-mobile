import 'package:flutter/material.dart';

import '../widgets/album_widgets.dart';

class AlbumListPage extends StatelessWidget {
  const AlbumListPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Albums')),
        body: const PagedAlbumGrid(),
      );
}
