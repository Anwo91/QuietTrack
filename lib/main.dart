// App entry point.
//
// Init order: Hive -> window_manager -> tray -> hotkey -> runApp

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/tray_service.dart';
import 'services/hotkey_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final startSilent = args.contains('--silent');

  // Storage (Hive)
  final storage = StorageService();
  await storage.init();

  // Window manager
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1000, 1000),
    minimumSize: Size(700, 500),
    center: true,
    title: 'QuietTrack',
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (!startSilent) {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  // Intercept close - hide to tray instead of quitting
  await windowManager.setPreventClose(true);

  // System tray
  final tray = TrayService();
  try {
    await tray.init();
  } catch (_) {
    // Tray is non-critical, keep going if it fails.
  }

  // Global hotkey (Ctrl+Alt+T)
  final hotkey = HotkeyService(tray: tray);
  hotkey.start();

  // Go
  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: QuietTrackApp(tray: tray),
    ),
  );
}

/// Root widget - wires up Material 3 theming (light / dark / system).
class QuietTrackApp extends ConsumerWidget {
  final TrayService tray;
  const QuietTrackApp({super.key, required this.tray});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'QuietTrack',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: HomeScreen(tray: tray),
    );
  }
}
