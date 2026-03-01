/// Shell with persistent sidebar + animated content swapping.
/// Intercepts window close to hide to tray instead of exiting.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../services/tray_service.dart';
import '../services/whats_new_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/sidebar.dart';
import 'dashboard_screen.dart';
import 'apps_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final TrayService tray;
  const HomeScreen({super.key, required this.tray});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  int _selectedIndex = 0;

  static const _screens = [
    DashboardScreen(),
    AppsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final storage = ref.read(storageServiceProvider);
      WhatsNewService.checkAndShow(context, storage);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// Intercept close → hide to tray or exit based on setting.
  @override
  void onWindowClose() async {
    final settings = ref.read(settingsProvider);
    if (settings.minimizeOnExit) {
      await widget.tray.hideWindow();
    } else {
      await widget.tray.exitApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Sidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) {
              ScaffoldMessenger.of(context).clearSnackBars();
              setState(() => _selectedIndex = i);
            },
          ),
          // Main content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, animation) {
                final reduceMotion =
                    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                if (reduceMotion) return child;

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_selectedIndex),
                child: _screens[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
