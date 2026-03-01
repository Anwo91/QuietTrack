/// Win32 API wrappers via dart:ffi.
///
/// Time counting rules:
///  - Total active = not idle (GetLastInputInfo)
///  - Per-app = foreground window seconds only
///  - Media = parallel counter, can overlap
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
part 'win32/win32_core_bindings.dart';
part 'win32/win32_monitor_bindings.dart';
part 'win32/win32_hotkey_bindings.dart';
part 'win32/win32_registry_bindings.dart';

// Win32Service - public API

class Win32Service {
  Win32Service._();

  /// Milliseconds since the last mouse/keyboard input event.
  /// Returns 0 on API failure (assume active).
  static int getIdleMs() {
    final pli = calloc<LASTINPUTINFO>();
    try {
      pli.ref.cbSize = sizeOf<LASTINPUTINFO>();
      final ok = _getLastInputInfo(pli);
      if (ok == 0) return 0; // API fail → assume active
      return _getTickCount() - pli.ref.dwTime;
    } finally {
      calloc.free(pli);
    }
  }

  /// HWND of the current foreground window (0 if none).
  static int getForegroundHwnd() => _getForegroundWindow();

  /// Full exe path for the process owning this window. Null if system/denied.
  static String? getExePath(int hwnd) {
    if (hwnd == 0) return null;
    final pPid = calloc<Uint32>();
    try {
      _getWindowThreadProcessId(hwnd, pPid);
      if (pPid.value == 0) return null;

      // PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
      final hProc = _openProcess(0x1000, 0, pPid.value);
      if (hProc == 0) return null;

      try {
        final buf = calloc<Uint16>(260);
        final pSize = calloc<Uint32>();
        pSize.value = 260;
        try {
          final ok = _queryFullProcessImageName(hProc, 0, buf.cast<Utf16>(), pSize);
          if (ok != 0) return buf.cast<Utf16>().toDartString();
          return null;
        } finally {
          calloc.free(buf);
          calloc.free(pSize);
        }
      } finally {
        _closeHandle(hProc);
      }
    } finally {
      calloc.free(pPid);
    }
  }

  static String appNameFromPath(String exePath) {
    final parts = exePath.split(RegExp(r'[/\\]'));
    final file = parts.last;
    return file.replaceAll(RegExp(r'\.exe$', caseSensitive: false), '');
  }

  /// Window title text (empty string if none).
  static String getWindowTitle(int hwnd) {
    if (hwnd == 0) return '';
    final len = _getWindowTextLength(hwnd);
    if (len <= 0) return '';
    final buf = calloc<Uint16>(len + 1);
    try {
      _getWindowText(hwnd, buf.cast<Utf16>(), len + 1);
      return buf.cast<Utf16>().toDartString();
    } finally {
      calloc.free(buf);
    }
  }

  /// Monitor name for the window's display.
  /// Uses MONITORINFOEXW → EnumDisplayDevices to resolve real device names
  /// like "DELL U2723QE" instead of "Display 1".
  static String getMonitorName(int hwnd) {
    if (hwnd == 0) return 'Primary';

    // MONITOR_DEFAULTTONEAREST = 2
    final hMon = _monitorFromWindow(hwnd, 2);
    if (hMon == 0) return 'Primary';

    return _monitorHandleToName(hMon);
  }

  /// Resolve a monitor handle to a friendly name.
  static String _monitorHandleToName(int hMon) {
    // Allocate MONITORINFOEXW (104 bytes) to get the device name (\\.\DISPLAY1).
    const miexSize = 104;
    final pBuf = calloc<Uint8>(miexSize);
    try {
      pBuf.cast<Uint32>().value = miexSize;
      final ok = _getMonitorInfo(hMon, pBuf.cast<MONITORINFO>());
      if (ok == 0) return 'Primary';

      // dwFlags at byte offset 36 (Uint32 index 9). MONITORINFOF_PRIMARY = 1.
      final flags = (pBuf.cast<Uint32>() + 9).value;
      final isPrimary = (flags & 0x1) != 0;

      // szDevice starts at byte offset 40, WCHAR[32] → e.g. "\\.\DISPLAY1"
      final szDevice = (pBuf + 40).cast<Utf16>().toDartString();

      // Try DisplayConfig API first (gives real names like "DELL U2723QE"),
      // fall back to EnumDisplayDevices if it fails.
      String label = _resolveViaDisplayConfig(szDevice)
          ?? _resolveViaEnumDisplayDevices(szDevice);
      if (isPrimary && !label.contains('Primary')) {
        label += ' (Primary)';
      }
      return label;
    } finally {
      calloc.free(pBuf);
    }
  }

  /// Cache of \\.\DISPLAYN → friendly name, built from DisplayConfig API.
  static Map<String, String>? _displayConfigCache;

  /// Build (or return cached) map of GDI device name → friendly monitor name
  /// using the modern QueryDisplayConfig + DisplayConfigGetDeviceInfo API.
  static void _buildDisplayConfigCache() {
    _displayConfigCache = {};
    final pNumPaths = calloc<Uint32>();
    final pNumModes = calloc<Uint32>();
    try {
      // Get buffer sizes
      var rc = _getDisplayConfigBufferSizes(_qdcOnlyActivePaths, pNumPaths, pNumModes);
      if (rc != 0) return;

      final numPaths = pNumPaths.value;
      final numModes = pNumModes.value;
      if (numPaths == 0) return;

      final pathArray = calloc<Uint8>(numPaths * _pathInfoSize);
      final modeArray = calloc<Uint8>(numModes * _modeInfoSize);
      try {
        pNumPaths.value = numPaths;
        pNumModes.value = numModes;
        rc = _queryDisplayConfig(
            _qdcOnlyActivePaths, pNumPaths, pathArray, pNumModes, modeArray, nullptr);
        if (rc != 0) return;

        final actualPaths = pNumPaths.value;
        for (var i = 0; i < actualPaths; i++) {
          final pathPtr = pathArray + (i * _pathInfoSize);

          // DISPLAYCONFIG_PATH_INFO layout:
          //   sourceInfo (20 bytes): adapterId (LUID 8 bytes) + id (4) + ...
          //   targetInfo (48 bytes) at offset 20: adapterId (8) + id (4) + ...

          // Extract target adapterId and id for the device info request
          // targetInfo.adapterId at offset 20 (LUID: low 4 + high 4)
          // targetInfo.id at offset 28

          // Build DISPLAYCONFIG_TARGET_DEVICE_NAME request packet
          // Header: type(4) + size(4) + adapterId(8) + id(4) = 20 bytes header
          // Then monitorFriendlyDeviceName at offset 80 (WCHAR[64] = 128 bytes)
          // And monitorDevicePath at offset 280 maybe... 
          // Total struct = 420 bytes

          final namePacket = calloc<Uint8>(_targetDeviceNameSize);
          try {
            // header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME (2)
            namePacket.cast<Uint32>().value = _deviceInfoGetTargetName;
            // header.size
            (namePacket.cast<Uint32>() + 1).value = _targetDeviceNameSize;
            // header.adapterId = copy from targetInfo
            (namePacket.cast<Uint32>() + 2).value =
                (pathPtr + 20).cast<Uint32>().value;     // adapterId.LowPart
            (namePacket.cast<Uint32>() + 3).value =
                (pathPtr + 24).cast<Uint32>().value;     // adapterId.HighPart
            // header.id = targetInfo.id
            (namePacket.cast<Uint32>() + 4).value =
                (pathPtr + 28).cast<Uint32>().value;

            final infoRc = _displayConfigGetDeviceInfo(namePacket);
            if (infoRc != 0) continue;

            // monitorFriendlyDeviceName at offset 36 in the struct, WCHAR[64]
            final friendlyName = (namePacket + 36).cast<Utf16>().toDartString();

            // Get the GDI device name to map back to \\.\.DISPLAYN
            // Use DISPLAYCONFIG_SOURCE_DEVICE_NAME (type=1) for that
            final sourcePacket = calloc<Uint8>(_sourceDeviceNameSize);
            try {
              sourcePacket.cast<Uint32>().value = 1; // DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME
              (sourcePacket.cast<Uint32>() + 1).value = _sourceDeviceNameSize;
              // adapterId from sourceInfo
              (sourcePacket.cast<Uint32>() + 2).value =
                  pathPtr.cast<Uint32>().value;          // sourceInfo.adapterId.LowPart
              (sourcePacket.cast<Uint32>() + 3).value =
                  (pathPtr + 4).cast<Uint32>().value;    // sourceInfo.adapterId.HighPart
              // sourceInfo.id
              (sourcePacket.cast<Uint32>() + 4).value =
                  (pathPtr + 8).cast<Uint32>().value;

              final srcRc = _displayConfigGetDeviceInfo(sourcePacket);
              if (srcRc == 0) {
                // viewGdiDeviceName at offset 20, WCHAR[32]
                final gdiName = (sourcePacket + 20).cast<Utf16>().toDartString();
                if (friendlyName.isNotEmpty && gdiName.isNotEmpty) {
                  _displayConfigCache![gdiName] = friendlyName;
                }
              }
            } finally {
              calloc.free(sourcePacket);
            }
          } finally {
            calloc.free(namePacket);
          }
        }
      } finally {
        calloc.free(pathArray);
        calloc.free(modeArray);
      }
    } finally {
      calloc.free(pNumPaths);
      calloc.free(pNumModes);
    }
  }

  /// Try to resolve a GDI device name (\\.\DISPLAY1) to a friendly monitor
  /// name using the DisplayConfig API. Returns null if not found.
  static String? _resolveViaDisplayConfig(String devicePath) {
    // Rebuild cache periodically (monitors can change)
    if (_displayConfigCache == null) {
      _buildDisplayConfigCache();
    }
    return _displayConfigCache?[devicePath];
  }

  /// Invalidate the cached display config names (called when monitors change).
  static void invalidateDisplayConfigCache() {
    _displayConfigCache = null;
  }

  /// Fallback: use EnumDisplayDevices to get the monitor name.
  static String _resolveViaEnumDisplayDevices(String devicePath) {
    if (devicePath.isEmpty) return 'Unknown';

    final lpDevice = devicePath.toNativeUtf16();
    final dd = calloc<Uint8>(_displayDeviceSize);
    try {
      dd.cast<Uint32>().value = _displayDeviceSize;
      final ok = _enumDisplayDevices(lpDevice.cast<Utf16>(), 0, dd, 0);
      if (ok != 0) {
        final deviceString = (dd + 68).cast<Utf16>().toDartString();
        if (deviceString.isNotEmpty &&
            deviceString != 'Generic PnP Monitor' &&
            !deviceString.startsWith('Default')) {
          return deviceString;
        }
      }
      // Fallback: parse "\\.\DISPLAY1" → "Display 1"
      final match = RegExp(r'DISPLAY(\d+)').firstMatch(devicePath);
      if (match != null) {
        return 'Display ${match.group(1)}';
      }
      return devicePath;
    } finally {
      calloc.free(lpDevice);
      calloc.free(dd);
    }
  }

  /// Returns the set of currently connected monitor names.
  /// Used by TrackerService to prune stale monitors.
  static Set<String> getActiveMonitorNames() {
    _enumeratedMonitors.clear();
    final cb = Pointer.fromFunction<_EnumDisplayMonitorsProc>(
        _monitorEnumCallback, 1);
    _enumDisplayMonitors(0, nullptr, cb, 0);
    return Set<String>.from(_enumeratedMonitors);
  }

  static final List<String> _enumeratedMonitors = [];

  static int _monitorEnumCallback(
      int hMonitor, int hdcMonitor, Pointer lprcMonitor, int dwData) {
    final name = _monitorHandleToName(hMonitor);
    _enumeratedMonitors.add(name);
    return 1; // continue enumeration
  }

  // Global hotkey (Ctrl+Alt+T)
  static const int _hotkeyId = 9001;

  static bool registerHotkey() {
    // MOD_CONTROL=0x0002, MOD_ALT=0x0001, VK_T=0x54
    return _registerHotKey(0, _hotkeyId, 0x0002 | 0x0001, 0x54) != 0;
  }

  static void unregisterHotkey() {
    _unregisterHotKey(0, _hotkeyId);
  }

  /// Check if Ctrl+Alt+T was pressed since last poll.
  static bool pollHotkey() {
    final msg = calloc<MSG>();
    try {
      // PM_REMOVE = 0x0001 - remove the message from the queue
      while (_peekMessage(msg, 0, 0x0312, 0x0312, 0x0001) != 0) {
        if (msg.ref.wParam == _hotkeyId) return true;
      }
      return false;
    } finally {
      calloc.free(msg);
    }
  }

  // Registry: Start with Windows

  static const _runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'QuietTrack';

  /// Add QuietTrack to HKCU\...\Run. Passes --silent if [silent] is true.
  static bool setStartupEnabled(String exePath, {bool silent = false}) {
    final subKey = _runKey.toNativeUtf16();
    final phKey = calloc<IntPtr>();
    try {
      // HKEY_CURRENT_USER = 0x80000001, KEY_SET_VALUE = 0x0002
      final res = _regOpenKeyEx(0x80000001, subKey, 0, 0x0002, phKey);
      if (res != 0) return false;
      final hKey = phKey.value;
      try {
        final valName = _valueName.toNativeUtf16();
        final value = silent ? '"$exePath" --silent' : '"$exePath"';
        final data = value.toNativeUtf16();
        final dataBytes = data.cast<Uint8>();
        // REG_SZ = 1, byte length includes null terminator
        final byteLen = (value.length + 1) * 2;
        try {
          final setRes = _regSetValueEx(hKey, valName, 0, 1, dataBytes, byteLen);
          return setRes == 0;
        } finally {
          calloc.free(valName);
          calloc.free(data);
        }
      } finally {
        _regCloseKey(hKey);
      }
    } finally {
      calloc.free(subKey);
      calloc.free(phKey);
    }
  }

  /// Remove QuietTrack from HKCU\...\Run.
  static bool removeStartupEntry() {
    final subKey = _runKey.toNativeUtf16();
    final phKey = calloc<IntPtr>();
    try {
      // HKEY_CURRENT_USER = 0x80000001, KEY_SET_VALUE = 0x0002
      final res = _regOpenKeyEx(0x80000001, subKey, 0, 0x0002, phKey);
      if (res != 0) return false;
      final hKey = phKey.value;
      try {
        final valName = _valueName.toNativeUtf16();
        try {
          final delRes = _regDeleteValue(hKey, valName);
          return delRes == 0;
        } finally {
          calloc.free(valName);
        }
      } finally {
        _regCloseKey(hKey);
      }
    } finally {
      calloc.free(subKey);
      calloc.free(phKey);
    }
  }
}
