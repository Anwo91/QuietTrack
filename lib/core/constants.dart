/// App-wide constants, defaults, Hive box names, media keywords, categories.
library;

class AppConstants {
  AppConstants._();

  static const String appName = 'QuietTrack';
  static const String appVersion = '1.0.0';

  /// 30 seconds of no mouse/keyboard = idle.
  /// Typical range: 10-60s. Under 10 marks reading/thinking as idle;
  /// over 60 misses short breaks. 30s is the sweet spot.
  static const int defaultIdleThresholdMs = 30000;

  /// Slider bounds for the idle-threshold setting.
  static const int minIdleThresholdMs = 5000;
  static const int maxIdleThresholdMs = 120000;

  // Hive boxes
  static const String settingsBox = 'quiettrack_settings';
  static const String trackingBox = 'quiettrack_tracking';

  /// Window title keywords for media/entertainment detection.
  /// Matched against lowercased window titles.
  static const List<String> defaultMediaKeywords = [
    'YouTube',
    'Netflix',
    'Twitch',
    'Prime Video',
    'Disney+',
    'Crunchyroll',
    'HBO Max',
    'Hulu',
    'Plex',
    'Spotify',
    'Apple Music',
    'VLC media player',
    'Movies & TV',
    'mpv',
  ];

  /// Keyword → category mapping. Matched against lowercased exe name.
  static const Map<String, String> defaultCategoryRules = {
    'chrome': 'Browser',
    'firefox': 'Browser',
    'msedge': 'Browser',
    'opera': 'Browser',
    'brave': 'Browser',
    'code': 'Development',
    'devenv': 'Development',
    'idea': 'Development',
    'android studio': 'Development',
    'teams': 'Communication',
    'discord': 'Communication',
    'slack': 'Communication',
    'zoom': 'Communication',
    'outlook': 'Communication',
    'explorer': 'System',
    'taskmgr': 'System',
    'cmd': 'System',
    'powershell': 'System',
    'winword': 'Productivity',
    'excel': 'Productivity',
    'powerpnt': 'Productivity',
    'notepad': 'Productivity',
    'onenote': 'Productivity',
    'spotify': 'Entertainment',
    'vlc': 'Entertainment',
  };
}
