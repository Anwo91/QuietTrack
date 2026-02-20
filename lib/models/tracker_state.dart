/// All the metrics the tracker produces each tick. Not persisted directly;
/// StorageService handles Hive serialization.
///
/// Time counting:
///  - totalActiveSeconds: every second the system wasn't idle
///  - appUsage[exePath]: foreground seconds per app
///  - mediaSeconds: parallel counter for media/entertainment time
library;

class TrackerState {
  final int totalActiveSeconds;
  final int mediaSeconds;
  final Map<String, int> appUsage;
  final Map<String, String> appNames;
  final Map<int, int> hourlyActive;
  final Map<String, int> monitorUsage;
  final Map<String, int> mediaAppUsage;
  final String? currentApp;
  final String? currentTitle;
  final String? currentMonitor;
  final String? currentMediaApp;
  final String? currentMediaTitle;
  final bool isTracking;
  final bool isLoading;
  final DateTime date;
  final List<SessionEntry> sessions;
  final Map<String, String> appCategories;
  /// Per-app window title usage: exePath → {title → seconds}
  final Map<String, Map<String, int>> windowTitleUsage;
  /// Per-monitor app usage: monitorName → {exePath → seconds}
  final Map<String, Map<String, int>> monitorAppUsage;

  const TrackerState({
    this.totalActiveSeconds = 0,
    this.mediaSeconds = 0,
    this.appUsage = const {},
    this.appNames = const {},
    this.hourlyActive = const {},
    this.monitorUsage = const {},
    this.mediaAppUsage = const {},
    this.currentApp,
    this.currentTitle,
    this.currentMonitor,
    this.currentMediaApp,
    this.currentMediaTitle,
    this.isTracking = false,
    this.isLoading = true,
    required this.date,
    this.sessions = const [],
    this.appCategories = const {},
    this.windowTitleUsage = const {},
    this.monitorAppUsage = const {},
  });

  factory TrackerState.initial() => TrackerState(
        date: DateTime.now(),
        isLoading: true,
      );

  TrackerState copyWith({
    int? totalActiveSeconds,
    int? mediaSeconds,
    Map<String, int>? appUsage,
    Map<String, String>? appNames,
    Map<int, int>? hourlyActive,
    Map<String, int>? monitorUsage,
    Map<String, int>? mediaAppUsage,
    String? currentApp,
    String? currentTitle,
    String? currentMonitor,
    String? currentMediaApp,
    String? currentMediaTitle,
    bool? isTracking,
    bool? isLoading,
    DateTime? date,
    List<SessionEntry>? sessions,
    Map<String, String>? appCategories,
    Map<String, Map<String, int>>? windowTitleUsage,
    Map<String, Map<String, int>>? monitorAppUsage,
  }) {
    return TrackerState(
      totalActiveSeconds: totalActiveSeconds ?? this.totalActiveSeconds,
      mediaSeconds: mediaSeconds ?? this.mediaSeconds,
      appUsage: appUsage ?? this.appUsage,
      appNames: appNames ?? this.appNames,
      hourlyActive: hourlyActive ?? this.hourlyActive,
      monitorUsage: monitorUsage ?? this.monitorUsage,
      mediaAppUsage: mediaAppUsage ?? this.mediaAppUsage,
      currentApp: currentApp ?? this.currentApp,
      currentTitle: currentTitle ?? this.currentTitle,
      currentMonitor: currentMonitor ?? this.currentMonitor,
      currentMediaApp: currentMediaApp ?? this.currentMediaApp,
      currentMediaTitle: currentMediaTitle ?? this.currentMediaTitle,
      isTracking: isTracking ?? this.isTracking,
      isLoading: isLoading ?? this.isLoading,
      date: date ?? this.date,
      sessions: sessions ?? this.sessions,
      appCategories: appCategories ?? this.appCategories,
      windowTitleUsage: windowTitleUsage ?? this.windowTitleUsage,
      monitorAppUsage: monitorAppUsage ?? this.monitorAppUsage,
    );
  }
}

/// One session in the timeline (app, start/end, optional title + monitor).
class SessionEntry {
  final String exePath;
  final String appName;
  final DateTime start;
  final DateTime end;
  final String? windowTitle;
  final String? monitorName;

  const SessionEntry({
    required this.exePath,
    required this.appName,
    required this.start,
    required this.end,
    this.windowTitle,
    this.monitorName,
  });

  int get durationSeconds => end.difference(start).inSeconds;

  Map<String, dynamic> toMap() => {
        'exePath': exePath,
        'appName': appName,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'windowTitle': windowTitle,
        'monitorName': monitorName,
      };

  factory SessionEntry.fromMap(Map<String, dynamic> m) => SessionEntry(
        exePath: (m['exePath'] as String?) ?? '',
        appName: (m['appName'] as String?) ?? 'Unknown',
        start: DateTime.tryParse(m['start']?.toString() ?? '') ?? DateTime.now(),
        end: DateTime.tryParse(m['end']?.toString() ?? '') ?? DateTime.now(),
        windowTitle: m['windowTitle'] as String?,
        monitorName: m['monitorName'] as String?,
      );
}
