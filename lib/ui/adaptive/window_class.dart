import 'package:flutter/widgets.dart';

/// How much room the app window has, which decides the whole layout:
///
/// * [compact]: phones and narrow windows. Bottom navigation, full-screen pages.
/// * [medium]: tablets in portrait and small windows. A navigation rail beside
///   the content.
/// * [expanded]: tablets in landscape, desktop and wide browser windows.
///
/// The thresholds follow Material 3's window size classes.
enum WindowClass {
  compact,
  medium,
  expanded;

  /// First width (in logical pixels) that counts as [medium].
  static const double mediumMinWidth = 600;

  /// First width (in logical pixels) that counts as [expanded].
  static const double expandedMinWidth = 1024;

  static WindowClass forWidth(double width) {
    if (width >= expandedMinWidth) return expanded;
    if (width >= mediumMinWidth) return medium;
    return compact;
  }

  /// The class for the window the widget is shown in. Rebuilds the caller
  /// whenever the window is resized across a breakpoint's width.
  static WindowClass of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;
  bool get isMedium => this == medium;
  bool get isExpanded => this == expanded;
}
