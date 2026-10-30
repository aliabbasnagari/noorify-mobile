import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Spotify-style tinted gradient behind the Now Playing art
/// (documentation/07-UI-DESIGN-SYSTEM.md §4.3, ported from
/// `ui/src/components/library/art-hero-background.tsx`): the dominant,
/// vibrancy-weighted color extracted from the cover art, fading down to the
/// theme background. Never jank on navigation — a neutral gradient is
/// visible immediately, and the tinted layer cross-fades in via opacity
/// once the color is ready (or already cached).
class ArtHeroBackground extends StatefulWidget {
  const ArtHeroBackground(
      {super.key, required this.imageUrl, this.height = 320});

  final Uri? imageUrl;
  final double height;

  @override
  State<ArtHeroBackground> createState() => _ArtHeroBackgroundState();
}

class _ArtHeroBackgroundState extends State<ArtHeroBackground> {
  // Shared across every instance so revisiting a track never redoes the
  // extraction, mirroring the web's module-level `cache` map.
  static final Map<String, Color?> _cache = {};

  Color? _color;

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void didUpdateWidget(covariant ArtHeroBackground old) {
    super.didUpdateWidget(old);
    if (widget.imageUrl != old.imageUrl) {
      // Reset immediately so the previous track's color never lingers.
      setState(() => _color = null);
      _extract();
    }
  }

  Future<void> _extract() async {
    final url = widget.imageUrl;
    if (url == null) return;
    final key = url.toString();
    if (_cache.containsKey(key)) {
      if (mounted) setState(() => _color = _cache[key]);
      return;
    }
    Color? color;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(key),
        size: const Size(64, 64),
        maximumColorCount: 12,
      );
      color = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;
    } on Object {
      // Unreachable art, decode failure, etc.: degrade to no gradient.
      color = null;
    }
    _cache[key] = color;
    if (mounted && widget.imageUrl == url) setState(() => _color = color);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final neutral = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [scheme.surfaceContainer, scheme.surface],
    );
    final tinted = _color == null
        ? null
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_color!, scheme.surface],
          );

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(gradient: neutral)),
          AnimatedOpacity(
            opacity: tinted == null ? 0 : 1,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            child: tinted == null
                ? const SizedBox.shrink()
                : DecoratedBox(decoration: BoxDecoration(gradient: tinted)),
          ),
        ],
      ),
    );
  }
}
