import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/local/app_database.dart';
import 'state/download_controller.dart';
import 'state/library_recents.dart';
import 'state/player_controller.dart';
import 'state/playlists_revision.dart';
import 'state/session_controller.dart';
import 'state/search_query.dart';
import 'state/settings_controller.dart';
import 'state/smart_playlist_store.dart';
import 'state/star_controller.dart';
import 'state/sync_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // just_audio has no native Windows/Linux backend of its own; this swaps in
  // libmpv (via media_kit) on those platforms. It leaves the other platforms
  // on their native players. The OS media session on desktop comes from
  // audio_service_win (SMTC) and audio_service_mpris, which register
  // themselves.
  if (!kIsWeb) JustAudioMediaKit.ensureInitialized();
  // PlayerController is also the AudioHandler driving the OS media
  // notification, lock screen, headset buttons and Android Auto.
  final playerController = await AudioService.init(
    builder: () => PlayerController(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.noorify.playback',
      androidNotificationChannelName: 'Noorify playback',
      androidNotificationOngoing: true,
    ),
  );
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()..restore()),
        ChangeNotifierProvider(create: (_) => SettingsController(prefs)),
        ChangeNotifierProvider(create: (_) => PlaylistsRevision()),
        ChangeNotifierProvider(create: (_) => SearchQuery()),
        ChangeNotifierProvider(create: (_) => LibraryRecents(prefs)),
        ChangeNotifierProvider(create: (_) => SmartPlaylistStore(prefs)),
        Provider(create: (_) => AppDatabase()),
        ChangeNotifierProxyProvider<SessionController, SyncController>(
          create: (context) => SyncController(context.read<AppDatabase>()),
          update: (_, session, sync) => sync!..attach(session.client),
        ),
        ChangeNotifierProxyProvider<SessionController, StarController>(
          create: (_) => StarController(),
          update: (_, session, stars) => stars!..attach(session.client),
        ),
        ChangeNotifierProxyProvider<SessionController, DownloadController>(
          create: (_) => DownloadController(),
          update: (_, session, downloads) => downloads!..attach(session.client),
        ),
        ChangeNotifierProxyProvider3<SessionController, SettingsController,
            DownloadController, PlayerController>(
          create: (_) => playerController,
          update: (_, session, settings, downloads, player) => player!
            ..attach(session.client)
            ..attachSettings(settings)
            ..attachDownloads(downloads),
        ),
      ],
      child: const NoorifyApp(),
    ),
  );
}
