import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/local/app_database.dart';
import 'state/download_controller.dart';
import 'state/player_controller.dart';
import 'state/session_controller.dart';
import 'state/settings_controller.dart';
import 'state/smart_playlist_store.dart';
import 'state/sync_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        ChangeNotifierProvider(create: (_) => SmartPlaylistStore(prefs)),
        Provider(create: (_) => AppDatabase()),
        ChangeNotifierProxyProvider<SessionController, SyncController>(
          create: (context) => SyncController(context.read<AppDatabase>()),
          update: (_, session, sync) => sync!..attach(session.client),
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
