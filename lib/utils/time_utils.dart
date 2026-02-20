/// Converts raw seconds to display strings ("2h 5m", "45s", etc.).
library;

class TimeUtils {
  TimeUtils._();

  /// Full format: `1h 23m 45s`.
  static String formatHMS(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h}h ${m}m ${s}s';
  }

  /// Short format: `2h 5m` or `45s`.
  static String formatShort(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  static String percent(int part, int total) {
    if (total <= 0) return '0.0%';
    return '${(part / total * 100).toStringAsFixed(1)}%';
  }

  /// Date key for Hive: `yyyy-MM-dd`.
  static String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';
}
