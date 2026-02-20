// Core tracker loop and accumulators.

import 'dart:async';
import '../models/tracker_state.dart';
import '../models/settings_model.dart';
import '../services/media_service.dart';
import '../services/win32_service.dart';
import '../utils/time_utils.dart';

class TrackerService {
  Timer? _pollTimer;
  final _stateController = StreamController<TrackerState>.broadcast();

  /// Stream of tracker state snapshots.
  Stream<TrackerState> get stateStream => _stateController.stream;

  // Mutable counters/maps, reset daily.
  int _totalActive = 0;
  int _mediaSeconds = 0;
  Map<String, int> _appUsage = {};
  Map<String, String> _appNames = {};
  Map<int, int> _hourlyActive = {};
  Map<String, int> _monitorUsage = {};
  Map<String, String> _appCategories = {};
  List<SessionEntry> _sessions = [];
  Map<String, Map<String, int>> _windowTitleUsage = {};
  Map<String, Map<String, int>> _monitorAppUsage = {};
  /// Per-source media seconds: appName -> seconds.
  Map<String, int> _mediaAppUsage = {};

  // Current foreground tracking
  String? _currentApp;
  String? _currentTitle;
  String? _currentMonitor;
  String? _currentMediaApp;
  String? _currentMediaTitle;
  DateTime? _sessionStart;
  String? _sessionApp;
  String? _sessionTitle;
  String? _sessionMonitor;
  int _monitorPruneCounter = 0;

  /// Consecutive fresh-input ticks needed before counting as active.
  int _activeStreak = 0;
  static const int _idleDebounce = 3;

  /// Max ms since last input to count as fresh input for debounce.
  static const int _freshInputMs = 1500;

  AppSettings _settings = AppSettings.defaults();
  DateTime _trackingDate = DateTime.now();

  /// Start the 1-second polling loop.
  void start({
    AppSettings? settings,
    int initialActive = 0,
    int initialMedia = 0,
    Map<String, int>? initialAppUsage,
    Map<String, String>? initialAppNames,
    Map<int, int>? initialHourly,
    Map<String, int>? initialMonitor,
    Map<String, String>? initialCategories,
    List<SessionEntry>? initialSessions,
    Map<String, Map<String, int>>? initialWindowTitleUsage,
    Map<String, Map<String, int>>? initialMonitorAppUsage,
    Map<String, int>? initialMediaAppUsage,
  }) {
    _settings = settings ?? AppSettings.defaults();
    _trackingDate = DateTime.now();
    _totalActive = initialActive;
    _mediaSeconds = initialMedia;
    _appUsage = Map<String, int>.from(initialAppUsage ?? {});
    _appNames = Map<String, String>.from(initialAppNames ?? {});
    _hourlyActive = Map<int, int>.from(initialHourly ?? {});
    _monitorUsage = Map<String, int>.from(initialMonitor ?? {});
    _appCategories = Map<String, String>.from(initialCategories ?? {});
    _sessions = List<SessionEntry>.from(initialSessions ?? []);
    _windowTitleUsage = initialWindowTitleUsage ?? {};
    _monitorAppUsage = initialMonitorAppUsage ?? {};
    _mediaAppUsage = Map<String, int>.from(initialMediaAppUsage ?? {});

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), _tick);

    // Start SMTC polling if media detection is enabled.
    if (_settings.detectMedia) MediaService.start();
  }

  /// Stop tracking.
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    MediaService.stop();
    _closeCurrentSession();
  }

  void updateSettings(AppSettings settings) {
    final wasMedia = _settings.detectMedia;
    _settings = settings;
    // Toggle SMTC polling with the setting.
    if (settings.detectMedia && !wasMedia) MediaService.start();
    if (!settings.detectMedia && wasMedia) MediaService.stop();
  }

  void dispose() {
    stop();
    _stateController.close();
  }

  // Runs once per second.
  void _tick(Timer timer) {
    final now = DateTime.now();

    _handleDayRollover(now);
    final idle = _updateIdle(now);
    final tick = _updateForeground(idle);
    _updateMedia(hwnd: tick.hwnd, exePath: tick.exePath, title: tick.title);
    _updateMonitor(hwnd: tick.hwnd, exePath: tick.exePath, idle: idle);
    _updateSessions(
      exePath: tick.exePath,
      title: tick.title,
      idle: idle,
      now: now,
    );
    _emitState();
  }

  void _handleDayRollover(DateTime now) {
    if (now.day != _trackingDate.day ||
        now.month != _trackingDate.month ||
        now.year != _trackingDate.year) {
      _closeCurrentSession();
      _resetForNewDay(now);
    }
  }

  bool _updateIdle(DateTime now) {
    final idleMs = Win32Service.getIdleMs();
    final longIdle = idleMs >= _settings.idleThresholdMs;
    final hasFreshInput = idleMs < _freshInputMs;

    if (longIdle) {
      // Past the threshold - reset streak so returning from idle is debounced.
      _activeStreak = 0;
    } else if (hasFreshInput) {
      if (_activeStreak < _idleDebounce) _activeStreak++;
    }
    // Between freshInputMs and the threshold: streak is preserved,
    // so a brief pause (e.g. reading) doesn't mark the user idle.

    final idle = longIdle || _activeStreak < _idleDebounce;
    if (!idle) {
      _totalActive++;
      final hour = now.hour;
      _hourlyActive[hour] = (_hourlyActive[hour] ?? 0) + 1;
    }
    return idle;
  }

  ({int hwnd, String? exePath, String? title}) _updateForeground(bool idle) {
    final hwnd = Win32Service.getForegroundHwnd();
    final exePath = Win32Service.getExePath(hwnd);
    String? title;

    if (_settings.trackWindowTitles) {
      title = Win32Service.getWindowTitle(hwnd);
    }

    if (exePath != null && !idle) {
      final ignored = _settings.ignoredApps.contains(exePath);
      if (!ignored) {
        _appUsage[exePath] = (_appUsage[exePath] ?? 0) + 1;

        if (!_appNames.containsKey(exePath)) {
          _appNames[exePath] = Win32Service.appNameFromPath(exePath);
        }

        if (_settings.trackWindowTitles && title != null && title.isNotEmpty) {
          _windowTitleUsage[exePath] ??= {};
          _windowTitleUsage[exePath]![title] =
              (_windowTitleUsage[exePath]![title] ?? 0) + 1;
        }

        if (_settings.enableAppCategories &&
            !_appCategories.containsKey(exePath)) {
          _appCategories[exePath] = _categorize(exePath, title);
        }
      }
    }

    _currentApp = exePath;
    _currentTitle = title;
    return (hwnd: hwnd, exePath: exePath, title: title);
  }

  void _updateMedia({
    required int hwnd,
    required String? exePath,
    required String? title,
  }) {
    if (!_settings.detectMedia) {
      _currentMediaApp = null;
      _currentMediaTitle = null;
      return;
    }

    final playingSessions =
        MediaService.allSessions.where((s) => s.isPlaying).toList(growable: false);
    if (playingSessions.isNotEmpty) {
      _mediaSeconds++;
      final primary = playingSessions.first;
      _currentMediaApp = primary.appName;
      _currentMediaTitle = primary.title;
      for (final session in playingSessions) {
        _mediaAppUsage[session.appName] = (_mediaAppUsage[session.appName] ?? 0) + 1;
      }
      return;
    }

    if (!MediaService.hasSessions) {
      final mediaTitle = title ?? Win32Service.getWindowTitle(hwnd);
      final lower = mediaTitle.toLowerCase();
      bool matched = false;
      for (final kw in _settings.mediaKeywords) {
        if (lower.contains(kw.toLowerCase())) {
          _mediaSeconds++;
          _currentMediaApp = _appNames[exePath] ?? 'Unknown';
          _currentMediaTitle = mediaTitle;
          _mediaAppUsage[_currentMediaApp!] =
              (_mediaAppUsage[_currentMediaApp!] ?? 0) + 1;
          matched = true;
          break;
        }
      }
      if (!matched) {
        _currentMediaApp = null;
        _currentMediaTitle = null;
      }
      return;
    }

    _currentMediaApp = null;
    _currentMediaTitle = null;
  }

  void _updateMonitor({
    required int hwnd,
    required String? exePath,
    required bool idle,
  }) {
    if (!_settings.trackPerMonitor || idle) return;

    final monName = Win32Service.getMonitorName(hwnd);
    _currentMonitor = monName;
    _monitorUsage[monName] = (_monitorUsage[monName] ?? 0) + 1;

    if (exePath != null) {
      _monitorAppUsage[monName] ??= {};
      _monitorAppUsage[monName]![exePath] =
          (_monitorAppUsage[monName]![exePath] ?? 0) + 1;
    }

    _monitorPruneCounter++;
    if (_monitorPruneCounter >= 30) {
      _monitorPruneCounter = 0;
      _pruneStaleMonitors();
    }
  }

  void _updateSessions({
    required String? exePath,
    required String? title,
    required bool idle,
    required DateTime now,
  }) {
    if (_settings.recordDetailedSessions && !idle) {
      _recordSession(exePath, title, _currentMonitor, now);
    } else if (idle) {
      _closeCurrentSession();
    }
  }

  void _emitState() {
    final ignored = _settings.ignoredApps.toSet();

    final filteredAppUsage = Map<String, int>.from(_appUsage)
      ..removeWhere((k, _) => ignored.contains(k));
    final filteredAppNames = Map<String, String>.from(_appNames)
      ..removeWhere((k, _) => ignored.contains(k));
    final filteredCategories = Map<String, String>.from(_appCategories)
      ..removeWhere((k, _) => ignored.contains(k));
    final filteredWindowTitles = Map<String, Map<String, int>>.from(_windowTitleUsage)
      ..removeWhere((k, _) => ignored.contains(k));
    final filteredSessions = _sessions
        .where((s) => !ignored.contains(s.exePath))
        .toList();
    final filteredMonitorApps = _monitorAppUsage.map((mon, apps) {
      final cleaned = Map<String, int>.from(apps)
        ..removeWhere((k, _) => ignored.contains(k));
      return MapEntry(mon, cleaned);
    });

    _stateController.add(TrackerState(
      totalActiveSeconds: _totalActive,
      mediaSeconds: _mediaSeconds,
      appUsage: Map.unmodifiable(filteredAppUsage),
      appNames: Map.unmodifiable(filteredAppNames),
      hourlyActive: Map.unmodifiable(_hourlyActive),
      monitorUsage: Map.unmodifiable(_monitorUsage),
      mediaAppUsage: Map.unmodifiable(_mediaAppUsage),
      currentApp: _currentApp,
      currentTitle: _currentTitle,
      currentMonitor: _currentMonitor,
      currentMediaApp: _currentMediaApp,
      currentMediaTitle: _currentMediaTitle,
      isTracking: true,
      isLoading: false,
      date: _trackingDate,
      sessions: List.unmodifiable(filteredSessions),
      appCategories: Map.unmodifiable(filteredCategories),
      windowTitleUsage: Map.unmodifiable(
        filteredWindowTitles.map(
          (k, v) => MapEntry(k, Map<String, int>.unmodifiable(v)),
        ),
      ),
      monitorAppUsage: Map.unmodifiable(
        filteredMonitorApps.map(
          (k, v) => MapEntry(k, Map<String, int>.unmodifiable(v)),
        ),
      ),
    ));
  }

  // Helpers

  /// Auto-categorize: first matching keyword wins.
  String _categorize(String exePath, String? title) {
    final lowerExe = exePath.toLowerCase();
    final lowerTitle = (title ?? '').toLowerCase();
    for (final rule in _settings.categoryRules) {
      final kw = (rule['keyword'] ?? '').toLowerCase();
      if (kw.isEmpty) continue;
      if (lowerExe.contains(kw) || lowerTitle.contains(kw)) {
        return rule['category'] ?? 'Other';
      }
    }
    return 'Other';
  }

  /// Record session transitions for the Timeline view.
  void _recordSession(String? exePath, String? title, String? monitor, DateTime now) {
    if (exePath == null) return;

    // Same app? Just extend the current session.
    if (_sessionApp == exePath) return;

    // Close previous session
    _closeCurrentSession();

    // Start new session
    _sessionStart = now;
    _sessionApp = exePath;
    _sessionTitle = title;
    _sessionMonitor = monitor;
  }

  void _closeCurrentSession() {
    if (_sessionStart != null && _sessionApp != null) {
      _sessions.add(SessionEntry(
        exePath: _sessionApp!,
        appName: _appNames[_sessionApp!] ?? Win32Service.appNameFromPath(_sessionApp!),
        start: _sessionStart!,
        end: DateTime.now(),
        windowTitle: _sessionTitle,
        monitorName: _sessionMonitor,
      ));
    }
    _sessionStart = null;
    _sessionApp = null;
    _sessionTitle = null;
    _sessionMonitor = null;
  }

  /// Reset accumulators for a new calendar day.
  void _resetForNewDay(DateTime newDate) {
    _trackingDate = newDate;
    _totalActive = 0;
    _mediaSeconds = 0;
    _appUsage = {};
    _appNames = {};
    _hourlyActive = {};
    _monitorUsage = {};
    _sessions = [];
    _appCategories = {};
    _windowTitleUsage = {};
    _monitorAppUsage = {};
    _mediaAppUsage = {};
    _monitorPruneCounter = 0;
  }

  /// Remove monitors from usage maps that are no longer connected.
  void _pruneStaleMonitors() {
    // Invalidate the DisplayConfig name cache so names are re-resolved
    Win32Service.invalidateDisplayConfigCache();

    final activeNames = Win32Service.getActiveMonitorNames();
    if (activeNames.isEmpty) return; // don't prune if enumeration failed

    _monitorUsage.removeWhere((key, _) => !activeNames.contains(key));
    _monitorAppUsage.removeWhere((key, _) => !activeNames.contains(key));
  }

  /// Manually set/override a single app's category.
  void setAppCategory(String exePath, String category) {
    _appCategories[exePath] = category;
    _emitState();
  }

  /// Get date key for storage.
  String get dateKey => TimeUtils.dateKey(_trackingDate);

  /// Serialize current state for Hive.
  Map<String, dynamic> exportState() => {
        'totalActiveSeconds': _totalActive,
        'mediaSeconds': _mediaSeconds,
        'appUsage': Map<String, int>.from(_appUsage),
        'appNames': Map<String, String>.from(_appNames),
        'hourlyActive':
            _hourlyActive.map((k, v) => MapEntry(k.toString(), v)),
        'monitorUsage': Map<String, int>.from(_monitorUsage),
        'appCategories': Map<String, String>.from(_appCategories),
        'sessions': _sessions.map((s) => s.toMap()).toList(),
        'windowTitleUsage': _windowTitleUsage.map(
          (k, v) => MapEntry(k, Map<String, int>.from(v)),
        ),
        'monitorAppUsage': _monitorAppUsage.map(
          (k, v) => MapEntry(k, Map<String, int>.from(v)),
        ),
        'mediaAppUsage': Map<String, int>.from(_mediaAppUsage),
      };

}
