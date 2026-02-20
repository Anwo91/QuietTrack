/// Settings: theme, advanced feature toggles, keyword/rule editors, updates.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/settings_provider.dart';
import '../providers/tracker_provider.dart';
import '../models/settings_model.dart';
import '../services/update_service.dart';
import '../services/update_ui_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _mediaKeywordCtrl;
  late TextEditingController _ruleKeywordCtrl;
  late TextEditingController _ruleCategoryCtrl;
  bool _rulesExpanded = false;

  // Update state
  UpdateStatus _updateStatus = UpdateStatus.idle;
  UpdateInfo? _updateInfo;
  double _downloadProgress = 0;
  String? _downloadedPath;
  String? _updateError;
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    _mediaKeywordCtrl = TextEditingController();
    _ruleKeywordCtrl = TextEditingController();
    _ruleCategoryCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(storageServiceProvider).loadLastUpdateCheck();
      if (saved != null && mounted) {
        setState(() => _lastChecked = saved);
      }
    });
  }

  @override
  void dispose() {
    _mediaKeywordCtrl.dispose();
    _ruleKeywordCtrl.dispose();
    _ruleCategoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          _buildGeneralSection(theme, settings, notifier),
          const SizedBox(height: 32),
          _buildAdvancedFeaturesSection(theme, settings, notifier),
          const SizedBox(height: 32),
          _buildIgnoredAppsSection(theme, settings, notifier),
          const SizedBox(height: 32),
          _buildDataSection(theme, notifier),
          const SizedBox(height: 32),
          _buildUpdatesSection(theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGeneralSection(
    ThemeData theme,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'General'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'light',
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode, size: 18)),
                    ButtonSegment(
                        value: 'dark',
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode, size: 18)),
                    ButtonSegment(
                        value: 'system',
                        label: Text('System'),
                        icon: Icon(Icons.settings_brightness, size: 18)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (sel) => notifier.setThemeMode(sel.first),
                ),
                const SizedBox(height: 20),
                Text('Idle threshold', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Time without input before you\u2019re considered idle.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${settings.idleThresholdMs ~/ 1000}s',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: settings.idleThresholdMs.toDouble(),
                        min: AppConstants.minIdleThresholdMs.toDouble(),
                        max: AppConstants.maxIdleThresholdMs.toDouble(),
                        divisions: (AppConstants.maxIdleThresholdMs -
                                AppConstants.minIdleThresholdMs) ~/
                            5000,
                        label: '${settings.idleThresholdMs ~/ 1000}s',
                        onChanged: (v) => notifier.setIdleThreshold(v.round()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedFeaturesSection(
    ThemeData theme,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'Advanced Features'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _toggle(
                theme: theme,
                title: 'Track window titles',
                subtitle:
                    'Record the title of the active window for richer reports.',
                value: settings.trackWindowTitles,
                onChanged: notifier.toggleTrackWindowTitles,
              ),
              const Divider(height: 1),
              _toggle(
                theme: theme,
                title: 'Detect media / entertainment',
                subtitle:
                    'Scan window titles for YouTube, Netflix, Spotify, etc.',
                value: settings.detectMedia,
                onChanged: notifier.toggleDetectMedia,
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _mediaKeywordEditor(settings, notifier),
                crossFadeState: settings.detectMedia
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
              const Divider(height: 1),
              _toggle(
                theme: theme,
                title: 'Record detailed sessions',
                subtitle:
                    'Store start/end times per app switch and show Timeline in Reports.',
                value: settings.recordDetailedSessions,
                onChanged: notifier.toggleDetailedSessions,
              ),            
              const Divider(height: 1),
              _toggle(
                theme: theme,
                title: 'Enable app categories',
                subtitle:
                    'Auto-categorize apps using a keyword → category rule set.',
                value: settings.enableAppCategories,
                onChanged: notifier.toggleAppCategories,
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _rulesEditor(settings, notifier),
                crossFadeState: settings.enableAppCategories
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
              const Divider(height: 1),
              _toggle(
                theme: theme,
                title: 'Track per-monitor activity',
                subtitle:
                    'Use MonitorFromWindow to track which monitor is active.',
                value: settings.trackPerMonitor,
                onChanged: notifier.togglePerMonitor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIgnoredAppsSection(
    ThemeData theme,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'Ignored Apps'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: settings.ignoredApps.isEmpty
                ? Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'No ignored apps. Right-click an app in the Apps tab to ignore it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : _ignoredAppsList(settings, notifier, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildDataSection(ThemeData theme, SettingsNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'Data'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset settings or delete all tracking history.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _confirmResetSettings(notifier),
                      icon: const Icon(Icons.settings_backup_restore, size: 16),
                      label: const Text('Reset Settings',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _confirmDeleteHistory(),
                      icon: const Icon(Icons.delete_forever, size: 16),
                      label: const Text('Delete All History',
                          style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdatesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'Updates'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _updateSection(theme),
          ),
        ),
      ],
    );
  }

  // Helpers──

  Widget _updateSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.update, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Current version: ${AppConstants.appVersion}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (_updateStatus == UpdateStatus.checking)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),

        // Status messages
        if (_updateStatus == UpdateStatus.available && _updateInfo != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  UpdateUiService.availableVersionMessage(_updateInfo!.version),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (_updateInfo!.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _updateInfo!.releaseNotes,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],

        if (_updateStatus == UpdateStatus.downloading) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],

        if (_updateStatus == UpdateStatus.error && _updateError != null) ...[
          const SizedBox(height: 8),
          Text(
            _updateError!,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
          ),
        ],

        const SizedBox(height: 12),

        Text(
          _lastChecked != null
              ? UpdateUiService.formatLastChecked(_lastChecked!)
              : 'Never checked',
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        // Action buttons
        Row(
          children: [
            if (_updateStatus == UpdateStatus.idle ||
                _updateStatus == UpdateStatus.error)
              FilledButton.icon(
                onPressed: _checkForUpdate,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Check for Updates', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (_updateStatus == UpdateStatus.available)
              FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download & Install', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (_updateStatus == UpdateStatus.ready)
              FilledButton.icon(
                onPressed: _applyUpdate,
                icon: const Icon(Icons.install_desktop, size: 16),
                label: const Text('Install & Restart', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: theme.colorScheme.tertiary,
                ),
              ),
            if (_updateStatus == UpdateStatus.checking) ...[
              const SizedBox(width: 8),
              Text(
                'Checking...',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _updateStatus = UpdateStatus.checking;
      _updateError = null;
    });

    final info = await UpdateService.checkForUpdate();
    final now = DateTime.now();
    await ref.read(storageServiceProvider).saveLastUpdateCheck(now);

    if (!mounted) return;

    setState(() => _lastChecked = now);

    if (info != null) {
      setState(() {
        _updateStatus = UpdateStatus.available;
        _updateInfo = info;
      });
    } else {
      setState(() {
        _updateStatus = UpdateStatus.error;
        _updateError = UpdateUiService.checkResultMessage(null);
      });
    }
  }

  Future<void> _startDownload() async {
    final info = _updateInfo;
    if (info == null) return;

    setState(() {
      _updateStatus = UpdateStatus.downloading;
      _downloadProgress = 0;
    });

    final path = await UpdateService.downloadUpdate(
      info,
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );

    if (!mounted) return;

    if (path != null) {
      setState(() {
        _updateStatus = UpdateStatus.ready;
        _downloadedPath = path;
      });
    } else {
      setState(() {
        _updateStatus = UpdateStatus.error;
        _updateError = 'Download failed. Please try again.';
      });
    }
  }

  Future<void> _applyUpdate() async {
    final path = _downloadedPath;
    if (path == null) return;

    final ok = await UpdateService.applyUpdate(path);
    if (ok) {
      // The batch script will handle replacement + relaunch.
      // Just exit the app cleanly.
      exit(0);
    } else {
      if (!mounted) return;
      setState(() {
        _updateStatus = UpdateStatus.error;
        _updateError = 'Failed to apply update. Try downloading again.';
      });
    }
  }

  void _confirmResetSettings(SettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text(
          'This will restore all settings to their defaults. '
          'Tracking history will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.resetToDefaults();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All History?'),
        content: const Text(
          'This will permanently delete all tracked app usage, '
          'sessions, and daily history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(trackerProvider.notifier).deleteAllHistory();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _toggle({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  // Media keyword editor
  Widget _mediaKeywordEditor(AppSettings settings, SettingsNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Media keywords:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: settings.mediaKeywords.map((kw) {
              return Chip(
                label: Text(kw, style: const TextStyle(fontSize: 11)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  final updated = List<String>.from(settings.mediaKeywords)
                    ..remove(kw);
                  notifier.setMediaKeywords(updated);
                },
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mediaKeywordCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Add keyword…',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _addMediaKeyword(settings, notifier),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _addMediaKeyword(settings, notifier),
                icon: const Icon(Icons.add, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ignoredAppsList(
      AppSettings settings, SettingsNotifier notifier, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${settings.ignoredApps.length} app${settings.ignoredApps.length == 1 ? '' : 's'} ignored',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...settings.ignoredApps.map((exePath) {
          final name = exePath.split(RegExp(r'[/\\]')).last;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.visibility_off,
                    size: 14, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: exePath,
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.restore, size: 16,
                      color: theme.colorScheme.primary),
                  tooltip: 'Stop ignoring',
                  onPressed: () => notifier.removeIgnoredApp(exePath),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _addMediaKeyword(AppSettings settings, SettingsNotifier notifier) {
    final kw = _mediaKeywordCtrl.text.trim();
    if (kw.isEmpty) return;
    final updated = List<String>.from(settings.mediaKeywords)..add(kw);
    notifier.setMediaKeywords(updated);
    _mediaKeywordCtrl.clear();
  }

  // Category rules editor - collapsible
  Widget _rulesEditor(AppSettings settings, SettingsNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _rulesExpanded = !_rulesExpanded),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _rulesExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Auto-categorization rules (${settings.categoryRules.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                ...settings.categoryRules.asMap().entries.map((entry) {
                  final rule = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${rule['keyword']} → ${rule['category']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () {
                            final updated =
                                List<Map<String, String>>.from(settings.categoryRules)
                                  ..removeAt(entry.key);
                            notifier.setCategoryRules(updated);
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ruleKeywordCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Keyword',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ruleCategoryCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Category',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _addRule(settings, notifier),
                      icon: const Icon(Icons.add, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            crossFadeState: _rulesExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  void _addRule(AppSettings settings, SettingsNotifier notifier) {
    final kw = _ruleKeywordCtrl.text.trim();
    final cat = _ruleCategoryCtrl.text.trim();
    if (kw.isEmpty || cat.isEmpty) return;
    final updated = List<Map<String, String>>.from(settings.categoryRules)
      ..add({'keyword': kw, 'category': cat});
    notifier.setCategoryRules(updated);
    _ruleKeywordCtrl.clear();
    _ruleCategoryCtrl.clear();
  }
}
