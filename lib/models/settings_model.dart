/// Settings model. Serialized to/from a Map for Hive.
/// All advanced features default to OFF.
library;

import '../core/constants.dart';

class AppSettings {
  final String themeMode; // 'light', 'dark', or 'system'

  // Advanced features
  final bool trackWindowTitles;
  final bool detectMedia;
  final bool recordDetailedSessions;
  final bool enableAppCategories;
  final bool showTimelineView;
  final bool trackPerMonitor;

  final List<String> mediaKeywords;
  final List<Map<String, String>> categoryRules; // [{keyword, category}]
  final int idleThresholdMs;
  final List<String> ignoredApps; // exe paths to ignore

  const AppSettings({
    this.themeMode = 'system',
    this.trackWindowTitles = false,
    this.detectMedia = false,
    this.recordDetailedSessions = false,
    this.enableAppCategories = false,
    this.showTimelineView = false,
    this.trackPerMonitor = false,
    this.mediaKeywords = const [],
    this.categoryRules = const [],
    this.idleThresholdMs = AppConstants.defaultIdleThresholdMs,
    this.ignoredApps = const [],
  });

  factory AppSettings.defaults() {
    return AppSettings(
      mediaKeywords: List<String>.from(AppConstants.defaultMediaKeywords),
      categoryRules: AppConstants.defaultCategoryRules.entries
          .map((e) => {'keyword': e.key, 'category': e.value})
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode,
        'trackWindowTitles': trackWindowTitles,
        'detectMedia': detectMedia,
        'recordDetailedSessions': recordDetailedSessions,
        'enableAppCategories': enableAppCategories,
        'showTimelineView': showTimelineView,
        'trackPerMonitor': trackPerMonitor,
        'mediaKeywords': mediaKeywords,
        'categoryRules': categoryRules,
        'idleThresholdMs': idleThresholdMs,
        'ignoredApps': ignoredApps,
      };

  factory AppSettings.fromMap(Map<dynamic, dynamic> m) {
    return AppSettings(
      themeMode: m['themeMode'] as String? ?? 'system',
      trackWindowTitles: m['trackWindowTitles'] as bool? ?? false,
      detectMedia: m['detectMedia'] as bool? ?? false,
      recordDetailedSessions: m['recordDetailedSessions'] as bool? ?? false,
      enableAppCategories: m['enableAppCategories'] as bool? ?? false,
      showTimelineView: m['showTimelineView'] as bool? ?? false,
      trackPerMonitor: m['trackPerMonitor'] as bool? ?? false,
      mediaKeywords: (m['mediaKeywords'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          List<String>.from(AppConstants.defaultMediaKeywords),
      categoryRules: (m['categoryRules'] as List?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          AppConstants.defaultCategoryRules.entries
              .map((e) => {'keyword': e.key, 'category': e.value})
              .toList(),
      idleThresholdMs:
          m['idleThresholdMs'] as int? ?? AppConstants.defaultIdleThresholdMs,
      ignoredApps: (m['ignoredApps'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  AppSettings copyWith({
    String? themeMode,
    bool? trackWindowTitles,
    bool? detectMedia,
    bool? recordDetailedSessions,
    bool? enableAppCategories,
    bool? showTimelineView,
    bool? trackPerMonitor,
    List<String>? mediaKeywords,
    List<Map<String, String>>? categoryRules,
    int? idleThresholdMs,
    List<String>? ignoredApps,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      trackWindowTitles: trackWindowTitles ?? this.trackWindowTitles,
      detectMedia: detectMedia ?? this.detectMedia,
      recordDetailedSessions:
          recordDetailedSessions ?? this.recordDetailedSessions,
      enableAppCategories: enableAppCategories ?? this.enableAppCategories,
      showTimelineView: showTimelineView ?? this.showTimelineView,
      trackPerMonitor: trackPerMonitor ?? this.trackPerMonitor,
      mediaKeywords: mediaKeywords ?? this.mediaKeywords,
      categoryRules: categoryRules ?? this.categoryRules,
      idleThresholdMs: idleThresholdMs ?? this.idleThresholdMs,
      ignoredApps: ignoredApps ?? this.ignoredApps,
    );
  }
}
