import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/download_controller.dart';
import '../../state/session_controller.dart';
import '../../subsonic/subsonic_client.dart';
import '../pages/album_page.dart';
import '../util.dart';
import 'cover_art.dart';

class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, this.width});

  final Album album;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => AlbumPage(albumId: album.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverArt(coverArt: album.coverArt, radius: 12),
                  if (context.select<DownloadController, bool>(
                    (d) => d.isCollectionOffline('album', album.id),
                  ))
                    const Positioned(
                      right: 6,
                      bottom: 6,
                      child: CircleAvatar(
                        radius: 12,
                        child: Icon(Icons.download_done, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
            Text(
              album.artist ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled horizontal row of albums for the home screen. Hidden entirely
/// when the server returns nothing (cf. Symfonium's `hideIfEmpty`).
class AlbumShelf extends StatefulWidget {
  const AlbumShelf({
    super.key,
    required this.title,
    required this.type,
    this.count = 20,
  });

  final String title;
  final AlbumListType type;
  final int count;

  @override
  State<AlbumShelf> createState() => _AlbumShelfState();
}

class _AlbumShelfState extends State<AlbumShelf> {
  late Future<List<Album>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final client = context.read<SessionController>().client!;
    _future = client.getAlbumList(widget.type, size: widget.count);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Album>>(
      future: _future,
      builder: (context, snap) {
        final albums = snap.data;
        if (albums != null && albums.isEmpty) return const SizedBox.shrink();

        Widget body;
        if (snap.hasError) {
          body = ErrorRetry(error: snap.error!, onRetry: () => setState(_load));
        } else if (albums == null) {
          body = const Center(child: CircularProgressIndicator());
        } else {
          body = ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => AlbumCard(album: albums[i], width: 150),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(widget.title,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            SizedBox(height: 210, child: body),
          ],
        );
      },
    );
  }
}

/// Infinite-scrolling album grid backed by `getAlbumList2` pagination.
class PagedAlbumGrid extends StatefulWidget {
  const PagedAlbumGrid({super.key, this.type = AlbumListType.alphabetical});

  final AlbumListType type;

  @override
  State<PagedAlbumGrid> createState() => _PagedAlbumGridState();
}

class _PagedAlbumGridState extends State<PagedAlbumGrid> {
  static const _pageSize = 60;

  final _albums = <Album>[];
  final _scroll = ScrollController();
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = context.read<SessionController>().client!;
      final page = await client.getAlbumList(
        widget.type,
        size: _pageSize,
        offset: _albums.length,
      );
      if (!mounted) return;
      setState(() {
        _albums.addAll(page);
        _done = page.length < _pageSize;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_albums.isEmpty) {
      if (_error != null) return ErrorRetry(error: _error!, onRetry: _loadMore);
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : const Center(child: Text('No albums'));
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        // Leaves more headroom than the art + two text lines strictly need
        // (was tuned tight enough that Manrope's taller line-height than the
        // old default font overflowed by ~2px) so a larger text-scale
        // accessibility setting doesn't reintroduce the same overflow.
        childAspectRatio: 0.72,
      ),
      itemCount: _albums.length,
      itemBuilder: (_, i) => AlbumCard(album: _albums[i]),
    );
  }
}
