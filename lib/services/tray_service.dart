/// System tray icon + context menu with Show/Hide/Exit.
library;

import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  bool _isVisible = true;
  bool get isVisible => _isVisible;

  Future<void> init() async {
    trayManager.addListener(this);

    // app_icon.ico must sit next to the exe (CMake copies it).
    final base = File(Platform.resolvedExecutable).parent.path;
    final icon = '$base\\app_icon.ico';

    if (File(icon).existsSync()) {
      await trayManager.setIcon(icon);
    }
    await trayManager.setToolTip('QuietTrack - Activity Tracker');

    await _buildMenu();
  }

  Future<void> _buildMenu() async {
    final menu = Menu(items: [
      MenuItem(key: 'show', label: 'Show QuietTrack'),
      MenuItem(key: 'hide', label: 'Hide to Tray'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: 'Exit'),
    ]);
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await showWindow();
        break;
      case 'hide':
        await hideWindow();
        break;
      case 'exit':
        await exitApp();
        break;
    }
  }

  @override
  void onTrayIconMouseDown() async {
    if (_isVisible) {
      await hideWindow();
    } else {
      await showWindow();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  Future<void> showWindow() async {
    _isVisible = true;
    await windowManager.show();
    await windowManager.focus();
    await _buildMenu();
  }

  Future<void> hideWindow() async {
    _isVisible = false;
    await windowManager.hide();
    await _buildMenu();
  }

  Future<void> toggleVisibility() async {
    if (_isVisible) {
      await hideWindow();
    } else {
      await showWindow();
    }
  }

  Future<void> exitApp() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}
