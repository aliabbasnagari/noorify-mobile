import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session_controller.dart';

/// Square cover art loaded from the server, with a placeholder fallback.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.coverArt,
    this.size,
    this.requestSize = 300,
    this.radius = 8,
  });

  final String? coverArt;

  /// Rendered size; null fills the available space (use inside a sized box).
  final double? size;

  /// Pixel size requested from the server.
  final int requestSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final client = context.read<SessionController>().client;
    final scheme = Theme.of(context).colorScheme;

    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.album, color: scheme.onSurfaceVariant),
      ),
    );

    Widget child = placeholder;
    if (coverArt != null && client != null) {
      child = CachedNetworkImage(
        // Auth salt is stable per client, but key on id+size so a re-login
        // doesn't invalidate the disk cache.
        cacheKey: 'cover:$coverArt:$requestSize',
        imageUrl: client.coverArtUrl(coverArt!, size: requestSize).toString(),
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}
