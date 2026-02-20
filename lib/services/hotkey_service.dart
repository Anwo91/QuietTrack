/// Global Ctrl+Alt+T hotkey via Win32 RegisterHotKey.
/// Polls every 100ms for the WM_HOTKEY message.
library;

import 'dart:async';
import 'tray_service.dart';
import 'win32_service.dart';

class HotkeyService {
  Timer? _pollTimer;
  final TrayService _tray;

  HotkeyService({required TrayService tray}) : _tray = tray;

  void start() {
    Win32Service.registerHotkey();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _poll(),
    );
  }

  void _poll() {
    if (Win32Service.pollHotkey()) {
      _tray.toggleVisibility();
    }
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    Win32Service.unregisterHotkey();
  }
}
