/// "What's New" dialog shown once after each app update.
/// Stores the last-seen version in Hive and compares against AppConstants.appVersion.
library;

import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'storage_service.dart';

class WhatsNewService {
  WhatsNewService._();

  /// Version-keyed changelog. Newest first.
  /// Each entry: version string → list of bullet points.
  static const Map<String, List<String>> changelog = {
    '1.0.0': [
      'Initial release.',
      'Dashboard with pie chart, hourly bar chart, active time counter, and media card.',
      'App tracking with searchable list, window title drilldown, and ignore/right-click support.',
      'Media detection via SMTC - tracks each source independently.',
      'Reports: Timeline (zoomable session bars), Graph (stacked daily bar chart with range picker), Categories (pie + expandable list), and Monitors (per-display breakdown).',
      'App categories with auto-categorization rules and manual per-app overrides.',
      'Per-monitor activity tracking.',
      'System tray integration and global hotkey (Ctrl+Alt+T).',
      'Self-update from GitHub Releases.',
    ],
  };

  /// Show the dialog if the app version is newer than what the user last saw.
  static Future<void> checkAndShow(BuildContext context, StorageService storage) async {
    final lastSeen = storage.loadLastSeenVersion();
    final current = AppConstants.appVersion;

    if (lastSeen == current) return;

    // Gather entries the user hasn't seen yet
    final newEntries = <String, List<String>>{};
    for (final entry in changelog.entries) {
      if (lastSeen == null || _isNewer(entry.key, lastSeen)) {
        newEntries[entry.key] = entry.value;
      }
    }

    if (newEntries.isEmpty) {
      // Version changed but no changelog entry - just update the marker.
      await storage.saveLastSeenVersion(current);
      return;
    }

    await storage.saveLastSeenVersion(current);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => _WhatsNewDialog(entries: newEntries),
    );
  }

  /// Simple semver comparison: a > b?
  static bool _isNewer(String a, String b) {
    final pa = a.split('.').map(int.tryParse).toList();
    final pb = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final va = (i < pa.length ? pa[i] : 0) ?? 0;
      final vb = (i < pb.length ? pb[i] : 0) ?? 0;
      if (va > vb) return true;
      if (va < vb) return false;
    }
    return false;
  }
}

class _WhatsNewDialog extends StatelessWidget {
  final Map<String, List<String>> entries;
  const _WhatsNewDialog({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 8),
          const Text("What's New"),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in entries.entries) ...[
                Text(
                  'v${entry.key}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                ...entry.value.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          )),
                          Expanded(
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
