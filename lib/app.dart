import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'settings/settings_models.dart';
import 'state/session_controller.dart';
import 'state/settings_controller.dart';
import 'ui/home_shell.dart';
import 'ui/login_page.dart';

/// Spotify's own brand green; identical in both themes.
const _spotifyGreen = Color(0xFF1DB954);

/// Explicit, hand-authored schemes matching `ui/`'s Spotify-exact palette
/// (see reference-documents/07-UI-DESIGN-SYSTEM.md §2.2) — `ColorScheme.fromSeed`
/// can't reproduce these, since Spotify's dark surfaces are flat near-black
/// steps rather than a chroma-derived tonal ramp.
final _darkScheme = ColorScheme.dark(
  surface: Colors.black,
  surfaceContainer: const Color(0xFF121212),
  surfaceContainerHigh: const Color(0xFF282828),
  primary: _spotifyGreen,
  onPrimary: Colors.black,
  onSurface: Colors.white,
  onSurfaceVariant: const Color(0xFFA7A7A7),
  secondaryContainer: const Color(0xFF282828),
  error: const Color(0xFFF15E6C),
  outlineVariant: Colors.white.withValues(alpha: 0.10),
);

final _lightScheme = ColorScheme.light(
  surface: Colors.white,
  surfaceContainer: const Color(0xFFF6F6F6),
  surfaceContainerHigh: Colors.white,
  primary: _spotifyGreen,
  onPrimary: Colors.black,
  onSurface: const Color(0xFF0A0A0A),
  onSurfaceVariant: const Color(0xFF6A6A6A),
  secondaryContainer: const Color(0xFFEFEFEF),
  error: const Color(0xFFD1293D),
  outlineVariant: Colors.black.withValues(alpha: 0.10),
);

ThemeData _themeFor(ColorScheme scheme) => ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // A clean geometric sans, closest available to Geist/Spotify Circular.
      textTheme: GoogleFonts.manropeTextTheme(
        ThemeData(brightness: scheme.brightness).textTheme,
      ),
    );

ThemeMode _toThemeMode(AppThemeMode mode) => switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

class NoorifyApp extends StatelessWidget {
  const NoorifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<SettingsController>().themeMode;
    return MaterialApp(
      title: 'Noorify',
      debugShowCheckedModeBanner: false,
      themeMode: _toThemeMode(themeMode),
      theme: _themeFor(_lightScheme),
      darkTheme: _themeFor(_darkScheme),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return session.isLoggedIn ? const HomeShell() : const LoginPage();
  }
}
