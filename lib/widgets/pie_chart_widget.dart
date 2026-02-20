// Donut chart of top apps with hover details.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme.dart';
import '../utils/time_utils.dart';

class AppPieChart extends StatefulWidget {
  final Map<String, int> appUsage;
  final Map<String, String> appNames;
  final int maxSlices;
  final Map<String, Map<String, int>> windowTitleUsage;

  const AppPieChart({
    super.key,
    required this.appUsage,
    required this.appNames,
    this.maxSlices = 6,
    this.windowTitleUsage = const {},
  });

  @override
  State<AppPieChart> createState() => _AppPieChartState();
}

class _AppPieChartState extends State<AppPieChart> {
  int _touchedIndex = -1;
  OverlayEntry? _overlayEntry;
  Offset _mousePosition = Offset.zero;

  /// Sorted top apps used by chart and legend.
  List<MapEntry<String, int>> get _topApps {
    final sorted = widget.appUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(widget.maxSlices).toList();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay();
    final topApps = _topApps;
    if (_touchedIndex < 0 || _touchedIndex >= topApps.length) return;

    final entry = topApps[_touchedIndex];
    final name = widget.appNames[entry.key] ?? entry.key;
    final secs = entry.value;
    final exePath = entry.key;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final screen = MediaQuery.of(context).size;
        // Offset to the right and slightly above cursor
        double left = _mousePosition.dx + 14;
        double top = _mousePosition.dy - 12;
        // Keep within screen bounds (clamp right edge)
        if (left + 230 > screen.width) {
          left = _mousePosition.dx - 234;
        }
        if (top < 8) top = 8;

        return Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: _hoverBadge(name, secs, exePath),
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _updateOverlayPosition() {
    _overlayEntry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections();
    if (sections.isEmpty) {
      return const Center(
        child: Text('No data yet', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: MouseRegion(
            onHover: (event) {
              _mousePosition = event.position;
              _updateOverlayPosition();
            },
            onExit: (_) {
              setState(() => _touchedIndex = -1);
              _removeOverlay();
            },
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    final idx =
                        response?.touchedSection?.touchedSectionIndex ?? -1;
                    if (_touchedIndex != idx) {
                      setState(() => _touchedIndex = idx);
                      if (idx >= 0) {
                        _showOverlay();
                      } else {
                        _removeOverlay();
                      }
                    }
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend with hover tooltips
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: _buildLegend(),
        ),
      ],
    );
  }

  int get _totalSeconds =>
      widget.appUsage.values.fold<int>(0, (a, b) => a + b);

  List<PieChartSectionData> _buildSections() {
    final topApps = _topApps;
    final sorted = widget.appUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // "Other" bucket
    final otherSeconds = sorted
        .skip(widget.maxSlices)
        .fold<int>(0, (sum, e) => sum + e.value);

    final total = _totalSeconds;
    final palette = AppTheme.chartPalette;
    final sections = <PieChartSectionData>[];

    for (var i = 0; i < topApps.length; i++) {
      final isTouched = _touchedIndex == i;
      final secs = topApps[i].value;
      final pct = total > 0 ? (secs / total * 100) : 0.0;
      sections.add(PieChartSectionData(
        value: secs.toDouble(),
        color: palette[i % palette.length],
        radius: isTouched ? 55 : 45,
        title: pct >= 5 ? '${pct.round()}%' : '',
        titleStyle: TextStyle(
          fontSize: isTouched ? 12 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    // "Other" slice
    if (otherSeconds > 0) {
      final idx = sections.length;
      final isTouched = _touchedIndex == idx;
      final pct = total > 0 ? (otherSeconds / total * 100) : 0.0;
      sections.add(PieChartSectionData(
        value: otherSeconds.toDouble(),
        color: Colors.grey.shade400,
        radius: isTouched ? 55 : 45,
        title: pct >= 5 ? '${pct.round()}%' : '',
        titleStyle: TextStyle(
          fontSize: isTouched ? 12 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    return sections;
  }

  /// Hover badge shown as an overlay following the cursor.
  Widget _hoverBadge(String appName, int secs, String exePath) {
    final titles = widget.windowTitleUsage[exePath];
    final hasTitles = titles != null && titles.isNotEmpty;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              TimeUtils.formatHMS(secs),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasTitles) ...[
              const SizedBox(height: 4),
              const Divider(height: 1),
              const SizedBox(height: 4),
              ..._topTitles(titles, 3),
            ],
          ],
        ),
      ),
    );
  }

  /// Top N window titles for the hover badge.
  List<Widget> _topTitles(Map<String, int> titles, int maxCount) {
    final sorted = titles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(maxCount).map((e) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                e.key,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              TimeUtils.formatShort(e.value),
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildLegend() {
    final topApps = _topApps;
    final sorted = widget.appUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final palette = AppTheme.chartPalette;
    final items = <Widget>[];

    final total = _totalSeconds;

    for (var i = 0; i < topApps.length; i++) {
      final name = widget.appNames[topApps[i].key] ?? topApps[i].key;
      final secs = topApps[i].value;
      final exePath = topApps[i].key;
      final pct = total > 0 ? (secs / total * 100).round() : 0;
      items.add(_legendItem(palette[i % palette.length], '$name  $pct%',
          tooltip: _legendTooltip(name, secs, exePath)));
    }

    if (sorted.length > widget.maxSlices) {
      final otherSecs = sorted
          .skip(widget.maxSlices)
          .fold<int>(0, (sum, e) => sum + e.value);
      final pct = total > 0 ? (otherSecs / total * 100).round() : 0;
      items.add(_legendItem(Colors.grey.shade400, 'Other  $pct%'));
    }

    return items;
  }

  /// Build tooltip text for legend items.
  String _legendTooltip(String appName, int secs, String exePath) {
    final buf = StringBuffer('$appName - ${TimeUtils.formatHMS(secs)}');
    final titles = widget.windowTitleUsage[exePath];
    if (titles != null && titles.isNotEmpty) {
      final sorted = titles.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final t in sorted.take(5)) {
        buf.write('\n  ${t.key} (${TimeUtils.formatShort(t.value)})');
      }
    }
    return buf.toString();
  }

  Widget _legendItem(Color color, String label, {String? tooltip}) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 300),
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: row,
        ),
      );
    }
    return row;
  }
}
