import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'window_class.dart';

/// Keeps content from stretching edge to edge on very wide windows: it is
/// centred and never wider than [maxWidth].
class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.child, this.maxWidth = 1400});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

/// The height of the text under a piece of artwork (a title and a subtitle
/// line), scaled with the user's text size so large text cannot overflow.
double artCardBodyHeight(BuildContext context, {double base = 60}) =>
    MediaQuery.textScalerOf(context).scale(base);

/// A grid of artwork tiles (square art with a title and subtitle under it)
/// that fills its width: it fits as many tiles as keep each no wider than
/// [maxTileWidth], then stretches them evenly. Each tile is as tall as its art
/// plus [bodyHeight] for the text, so unlike a fixed aspect ratio it stays
/// correct at any width and text size.
class ArtGridDelegate extends SliverGridDelegate {
  const ArtGridDelegate({
    required this.bodyHeight,
    this.maxTileWidth = 190,
    this.crossSpacing = 12,
    this.mainSpacing = 16,
  });

  /// Uses the current text size for [bodyHeight].
  factory ArtGridDelegate.of(
    BuildContext context, {
    double maxTileWidth = 190,
  }) =>
      ArtGridDelegate(
        bodyHeight: artCardBodyHeight(context),
        maxTileWidth: maxTileWidth,
      );

  final double bodyHeight;
  final double maxTileWidth;
  final double crossSpacing;
  final double mainSpacing;

  /// How many tiles fit across [crossAxisExtent].
  int columnsFor(double crossAxisExtent) => math.max(
        1,
        ((crossAxisExtent + crossSpacing) / (maxTileWidth + crossSpacing))
            .ceil(),
      );

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final columns = columnsFor(constraints.crossAxisExtent);
    final tileWidth =
        (constraints.crossAxisExtent - crossSpacing * (columns - 1)) / columns;
    final tileHeight = tileWidth + bodyHeight;
    return SliverGridRegularTileLayout(
      crossAxisCount: columns,
      mainAxisStride: tileHeight + mainSpacing,
      crossAxisStride: tileWidth + crossSpacing,
      childMainAxisExtent: tileHeight,
      childCrossAxisExtent: tileWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(ArtGridDelegate old) =>
      old.bodyHeight != bodyHeight ||
      old.maxTileWidth != maxTileWidth ||
      old.crossSpacing != crossSpacing ||
      old.mainSpacing != mainSpacing;
}

/// A titled row of artwork cards.
///
/// On a phone it is a horizontal scroller with fixed-width cards, the next one
/// peeking in so it is clear there is more. On wider windows the cards stretch
/// so a whole number of them fills the row, with arrows beside the title to
/// page through the rest, because there is no finger to swipe with.
/// [onShowAll], if given, adds a "Show all" button.
class AdaptiveShelf extends StatefulWidget {
  const AdaptiveShelf({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.onShowAll,
    this.showAllLabel = 'Show all',
    this.compactCardWidth = 150,
    this.maxCardWidth = 190,
  });

  final String title;
  final int itemCount;

  /// Builds one card, [width] wide; the card is as tall as its art plus the
  /// text under it.
  final Widget Function(BuildContext context, int index, double width)
      itemBuilder;
  final VoidCallback? onShowAll;

  /// The text of the button added by [onShowAll].
  final String showAllLabel;

  /// Card width on a phone.
  final double compactCardWidth;

  /// The widest a card gets on wider windows.
  final double maxCardWidth;

  @override
  State<AdaptiveShelf> createState() => _AdaptiveShelfState();
}

class _AdaptiveShelfState extends State<AdaptiveShelf> {
  static const _gap = 12.0;

  final _scroll = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateArrows);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final back = position.pixels > 1;
    final forward = position.pixels < position.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  void _page(int direction, double pageExtent) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + direction * pageExtent)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = !WindowClass.of(context).isCompact;
    final padding = wide ? 24.0 : 16.0;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth - 2 * padding;

      // Wide: as many cards as fit, stretched to fill. Phone: fixed width.
      final visibleCount = wide
          ? math.max(
              2, ((available + _gap) / (widget.maxCardWidth + _gap)).ceil())
          : null;
      final cardWidth = visibleCount == null
          ? widget.compactCardWidth
          : (available - _gap * (visibleCount - 1)) / visibleCount;
      final height = cardWidth + artCardBodyHeight(context);
      final pageExtent = visibleCount == null
          ? available
          : (cardWidth + _gap) * visibleCount;

      // Arrow state depends on the laid-out scroll extent.
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padding, 16, padding - 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge,
                  ),
                ),
                if (wide) ...[
                  IconButton(
                    tooltip: 'Scroll left',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _canBack ? () => _page(-1, pageExtent) : null,
                  ),
                  IconButton(
                    tooltip: 'Scroll right',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _canForward ? () => _page(1, pageExtent) : null,
                  ),
                ],
                if (widget.onShowAll != null)
                  TextButton(
                    onPressed: widget.onShowAll,
                    child: Text(widget.showAllLabel),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: height,
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding),
              itemCount: widget.itemCount,
              separatorBuilder: (_, __) => const SizedBox(width: _gap),
              itemBuilder: (context, i) =>
                  widget.itemBuilder(context, i, cardWidth),
            ),
          ),
        ],
      );
    });
  }
}
