/// Reports: charts, timeline, per-monitor breakdown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme.dart';
import '../models/settings_model.dart';
import '../models/tracker_state.dart';
import '../providers/tracker_provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import '../utils/time_utils.dart';
import '../widgets/timeline_view.dart';
import '../widgets/animated_card.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// How many days to show in Graph and Timeline. 0 = all.
  int _selectedRange = 7;

  /// Graph legend filter: if non-null, only show this app in the chart.
  String? _graphFilterApp;

  void _syncTabControllerLength(int length) {
    if (_tabController.length == length) return;
    _tabController.dispose();
    _tabController = TabController(length: length, initialIndex: 0, vsync: this);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  int get _tabCount {
    final s = ref.read(settingsProvider);
    int count = 1; // Graph always shown
    if (s.recordDetailedSessions) count++;
    if (s.enableAppCategories) count++;
    if (s.trackPerMonitor) count++;
    return count;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTabControllerLength(_tabCount);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackerProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final storage = ref.watch(storageServiceProvider);
    final tabItems = _buildTabItems(
      settings: settings,
      state: state,
      storage: storage,
      theme: theme,
    );

    _syncTabControllerLength(tabItems.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Reports',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Range picker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(20),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedRange,
                    isDense: true,
                    icon: Icon(Icons.expand_more, size: 18,
                      color: theme.colorScheme.onSurfaceVariant),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 days')),
                      DropdownMenuItem(value: 14, child: Text('14 days')),
                      DropdownMenuItem(value: 30, child: Text('30 days')),
                      DropdownMenuItem(value: 90, child: Text('90 days')),
                      DropdownMenuItem(value: 0, child: Text('All time')),
                    ],
                    onChanged: (v) => setState(() => _selectedRange = v ?? 0),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Tabs
        TabBar(
          controller: _tabController,
          tabs: tabItems.map((item) => item.tab).toList(),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        const SizedBox(height: 8),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: tabItems.map((item) => item.view).toList(),
          ),
        ),
      ],
    );
  }

  List<_ReportTabItem> _buildTabItems({
    required AppSettings settings,
    required TrackerState state,
    required StorageService storage,
    required ThemeData theme,
  }) {
    final items = <_ReportTabItem>[];

    if (settings.recordDetailedSessions) {
      items.add(_ReportTabItem(const Tab(text: 'Timeline'), _timelineTab(state, storage, settings.ignoredApps)));
    }

    items.add(_ReportTabItem(const Tab(text: 'Graph'), _graphTab(storage, theme, settings.ignoredApps)));

    if (settings.enableAppCategories) {
      items.add(_ReportTabItem(const Tab(text: 'Categories'), _categoriesTab(state, theme)));
    }

    if (settings.trackPerMonitor) {
      items.add(_ReportTabItem(const Tab(text: 'Monitors'), _monitorsTab(state, theme)));
    }
    return items;
  }

  // Graph tab - stacked bar chart showing per-app breakdown.
  Widget _graphTab(StorageService storage, ThemeData theme, List<String> ignoredApps) {
    final ignoredSet = ignoredApps.toSet();
    var keys = storage.getAllDateKeys();
    if (keys.isEmpty) {
      return const Center(child: Text('No historical data yet.'));
    }

    // Apply range filter
    if (_selectedRange > 0 && keys.length > _selectedRange) {
      keys = keys.sublist(keys.length - _selectedRange);
    }

    // Load days
    final dayEntries = <_GraphDay>[];
    final appTotals = <String, int>{}; // for sorting top apps

    for (final key in keys) {
      final data = storage.loadDayData(key);
      final appUsage = data['appUsage'] != null
          ? (Map<String, int>.from(
              (data['appUsage'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as int?) ?? 0),
              ),
            )..removeWhere((k, _) => ignoredSet.contains(k)))
          : <String, int>{};
      final appNames = data['appNames'] != null
          ? (Map<String, String>.from(
              (data['appNames'] as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ),
            )..removeWhere((k, _) => ignoredSet.contains(k)))
          : <String, String>{};

      dayEntries.add(_GraphDay(
        dateKey: key,
        appUsage: appUsage,
        appNames: appNames,
      ));

      for (final entry in appUsage.entries) {
        final name = appNames[entry.key] ?? entry.key.split(RegExp(r'[/\\]')).last.replaceAll('.exe', '');
        appTotals[name] = (appTotals[name] ?? 0) + entry.value;
      }
    }

    // Pick top N apps by total usage, rest → "Other"
    const maxApps = 8;
    final sortedApps = appTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topApps = sortedApps.take(maxApps).map((e) => e.key).toSet();

    // Build stacked data
    final palette = AppTheme.chartPalette;
    final appColors = <String, Color>{};
    int colorIdx = 0;
    for (final app in topApps) {
      appColors[app] = palette[colorIdx % palette.length];
      colorIdx++;
    }
    appColors['Other'] = Colors.grey.shade400;

    final allApps = [...topApps, if (sortedApps.length > maxApps) 'Other'];
    final maxHours = <double>[0.0];

    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < dayEntries.length; i++) {
      final day = dayEntries[i];
      final appHours = <String, double>{};

      for (final entry in day.appUsage.entries) {
        final name = day.appNames[entry.key] ??
            entry.key.split(RegExp(r'[/\\]')).last.replaceAll('.exe', '');
        final bucket = topApps.contains(name) ? name : 'Other';
        appHours[bucket] = (appHours[bucket] ?? 0) + entry.value / 3600;
      }

      // Build stacked rod (filtered by legend selection)
      double cumulative = 0;
      final rodStacks = <BarChartRodStackItem>[];
      for (final app in allApps) {
        final hrs = appHours[app] ?? 0;
        if (hrs <= 0) continue;
        if (_graphFilterApp != null && app != _graphFilterApp) {
          continue;
        }
        rodStacks.add(BarChartRodStackItem(
          cumulative,
          cumulative + hrs,
          appColors[app]!,
        ));
        cumulative += hrs;
      }

      if (cumulative > maxHours[0]) maxHours[0] = cumulative;

      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: cumulative,
            width: dayEntries.length > 60 ? 4 : dayEntries.length > 30 ? 8 : 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            rodStackItems: rodStacks,
          ),
        ],
      ));
    }

    final labels = dayEntries.map((d) => d.dateKey.substring(5)).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: AnimatedCard(
        index: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Usage (${dayEntries.length} days)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Legend (clickable to filter)
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                ...allApps.map((name) {
                  final isSelected = _graphFilterApp == null || _graphFilterApp == name;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _graphFilterApp = _graphFilterApp == name ? null : name;
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Opacity(
                        opacity: isSelected ? 1.0 : 0.3,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: appColors[name],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(name, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (_graphFilterApp != null)
                  GestureDetector(
                    onTap: () => setState(() => _graphFilterApp = null),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restart_alt, size: 12, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Text('Reset', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: barGroups,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 0.5,
                        getTitlesWidget: (v, _) {
                          final isWhole = (v * 2).round() % 2 == 0;
                          return Text(
                            isWhole ? '${v.toInt()}h' : '${v.toInt()}:30',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          // Show every Nth label to avoid overlap
                          final step = (labels.length / 12).ceil().clamp(1, 100);
                          if (idx % step != 0 && idx != labels.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Transform.rotate(
                            angle: labels.length > 14 ? -0.5 : 0,
                            child: Text(
                              labels[idx],
                              style: TextStyle(
                                fontSize: 9,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      tooltipRoundedRadius: 8,
                      direction: TooltipDirection.top,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      tooltipBorder: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                      getTooltipColor: (_) => theme.colorScheme.surfaceContainer,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex < 0 || groupIndex >= dayEntries.length) {
                          return null;
                        }
                        final day = dayEntries[groupIndex];
                        final buf = StringBuffer();
                        buf.writeln(labels[groupIndex]);
                        double totalHrs = 0;
                        for (final app in allApps) {
                          double hrs = 0;
                          for (final e in day.appUsage.entries) {
                            final name = day.appNames[e.key] ??
                                e.key.split(RegExp(r'[/\\]')).last.replaceAll('.exe', '');
                            final bucket = topApps.contains(name) ? name : 'Other';
                            if (bucket == app) hrs += e.value / 3600;
                          }
                          if (hrs > 0.01) {
                            totalHrs += hrs;
                            final mins = (hrs * 60).round();
                            final h = mins ~/ 60;
                            final m = mins % 60;
                            final time = h > 0
                                ? '${h}h ${m.toString().padLeft(2, '0')}m'
                                : '${m}m';
                            buf.writeln('$app: $time');
                          }
                        }
                        // Total line
                        final totalMins = (totalHrs * 60).round();
                        final th = totalMins ~/ 60;
                        final tm = totalMins % 60;
                        final totalStr = th > 0
                            ? '${th}h ${tm.toString().padLeft(2, '0')}m'
                            : '${tm}m';
                        buf.write('Total: $totalStr');
                        return BarTooltipItem(
                          buf.toString(),
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Timeline tab
  Widget _timelineTab(TrackerState state, StorageService storage, List<String> ignoredApps) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AnimatedCard(
        index: 0,
        child: TimelineView(
          sessions: state.sessions,
          storage: storage,
          maxDays: _selectedRange > 0 ? _selectedRange : null,
          ignoredApps: ignoredApps.toSet(),
        ),
      ),
    );
  }

  // Categories tab - pie chart + list breakdown by category.
  Widget _categoriesTab(TrackerState state, ThemeData theme) {
    if (state.appCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No categorized apps yet.\nCategories are assigned as you use apps.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // Aggregate time by category
    final categoryTime = <String, int>{};
    final categoryApps = <String, List<MapEntry<String, int>>>{};
    for (final entry in state.appUsage.entries) {
      final cat = state.appCategories[entry.key] ?? 'Other';
      categoryTime[cat] = (categoryTime[cat] ?? 0) + entry.value;
      categoryApps.putIfAbsent(cat, () => []);
      categoryApps[cat]!.add(entry);
    }

    final sorted = categoryTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);

    final palette = AppTheme.chartPalette;
    final catColors = <String, Color>{};
    for (var i = 0; i < sorted.length; i++) {
      catColors[sorted[i].key] = palette[i % palette.length];
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: AnimatedCard(
        index: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category Breakdown', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            // Pie chart
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: sorted.map((e) {
                    final pct = total > 0 ? (e.value / total * 100) : 0.0;
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      color: catColors[e.key],
                      radius: 50,
                      title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Category list with expandable app details
            Expanded(
              child: _CategoryList(
                sorted: sorted,
                catColors: catColors,
                categoryApps: categoryApps,
                appNames: state.appNames,
                total: total,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Monitors tab - show per-monitor time with app breakdown
  Widget _monitorsTab(TrackerState state, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AnimatedCard(
        index: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monitor Activity', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (state.monitorUsage.isEmpty)
              const Text('No monitor data yet.')
            else
              Expanded(
                child: _MonitorAppList(
                  monitorUsage: state.monitorUsage,
                  monitorAppUsage: state.monitorAppUsage,
                  appNames: state.appNames,
                ),
              ),
          ],
        ),
      ),
    );
  }


}

class _ReportTabItem {
  final Tab tab;
  final Widget view;

  const _ReportTabItem(this.tab, this.view);
}

/// Collapsible per-monitor app list for the Monitors tab.
class _MonitorAppList extends StatefulWidget {
  final Map<String, int> monitorUsage;
  final Map<String, Map<String, int>> monitorAppUsage;
  final Map<String, String> appNames;

  const _MonitorAppList({
    required this.monitorUsage,
    required this.monitorAppUsage,
    required this.appNames,
  });

  @override
  State<_MonitorAppList> createState() => _MonitorAppListState();
}

class _MonitorAppListState extends State<_MonitorAppList> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = widget.monitorUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final mon = sorted[index];
        final apps = widget.monitorAppUsage[mon.key] ?? {};
        final isExpanded = _expanded.contains(mon.key);
        final sortedApps = apps.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: apps.isNotEmpty
                  ? () => setState(() {
                        if (isExpanded) {
                          _expanded.remove(mon.key);
                        } else {
                          _expanded.add(mon.key);
                        }
                      })
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.monitor, size: 18),
                    const SizedBox(width: 8),
                    if (apps.isNotEmpty)
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(mon.key, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      TimeUtils.formatHMS(mon.value),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              ...sortedApps.map((app) {
                final name = widget.appNames[app.key] ??
                    app.key.split(RegExp(r'[/\\]')).last.replaceAll('.exe', '');
                return Padding(
                  padding:
                      const EdgeInsets.only(left: 48, top: 2, bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.apps, size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        TimeUtils.formatHMS(app.value),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

/// Expandable category list for the Categories tab.
class _CategoryList extends StatefulWidget {
  final List<MapEntry<String, int>> sorted;
  final Map<String, Color> catColors;
  final Map<String, List<MapEntry<String, int>>> categoryApps;
  final Map<String, String> appNames;
  final int total;

  const _CategoryList({
    required this.sorted,
    required this.catColors,
    required this.categoryApps,
    required this.appNames,
    required this.total,
  });

  @override
  State<_CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<_CategoryList> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      itemCount: widget.sorted.length,
      itemBuilder: (context, index) {
        final cat = widget.sorted[index];
        final pct = widget.total > 0
            ? (cat.value / widget.total * 100).toStringAsFixed(1)
            : '0';
        final isExpanded = _expanded.contains(cat.key);
        final apps = widget.categoryApps[cat.key] ?? [];
        final sortedApps = apps.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: apps.isNotEmpty
                  ? () => setState(() {
                        if (isExpanded) {
                          _expanded.remove(cat.key);
                        } else {
                          _expanded.add(cat.key);
                        }
                      })
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: widget.catColors[cat.key],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (apps.isNotEmpty)
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        cat.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      TimeUtils.formatHMS(cat.value),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              ...sortedApps.map((app) {
                final name = widget.appNames[app.key] ??
                    app.key
                        .split(RegExp(r'[/\\]'))
                        .last
                        .replaceAll('.exe', '');
                return Padding(
                  padding: const EdgeInsets.only(left: 48, top: 2, bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.apps, size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        TimeUtils.formatHMS(app.value),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

class _GraphDay {
  final String dateKey;
  final Map<String, int> appUsage;
  final Map<String, String> appNames;

  const _GraphDay({
    required this.dateKey,
    required this.appUsage,
    required this.appNames,
  });
}
