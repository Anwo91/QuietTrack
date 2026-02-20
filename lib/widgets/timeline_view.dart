/// Timeline view showing all tracked days.
/// Hover over a row to zoom into that time region; move mouse away to reset.
library;

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tracker_state.dart';
import '../core/theme.dart';
import '../services/storage_service.dart';
import '../utils/time_utils.dart';

class TimelineView extends StatefulWidget {
  /// Today's live sessions (already in memory).
  final List<SessionEntry> sessions;

  /// Used to load previous days from Hive.
  final StorageService storage;

  /// Maximum number of days to show (null = all).
  final int? maxDays;

  /// Exe paths to exclude from timeline.
  final Set<String> ignoredApps;

  const TimelineView({
    super.key,
    required this.sessions,
    required this.storage,
    this.maxDays,
    this.ignoredApps = const {},
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  /// Which day-index (0-2) is being zoomed, -1 = none.
  int _zoomedDay = -1;
  double _zoomCenter = 0.5;
  double _zoomLevel = 1.0;
  static const double _maxZoom = 12.0;

  /// Legend filter: if non-null, only show this app.
  String? _filterApp;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = <_DayData>[];
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    // Always include today first
    days.add(_DayData(date: today, sessions: widget.sessions));

    // Load all stored days from history
    final allKeys = widget.storage.getAllDateKeys()
      ..sort((a, b) => b.compareTo(a)); // newest first
    for (final key in allKeys) {
      if (key == todayKey) continue; // already added
      if (widget.maxDays != null && days.length >= widget.maxDays!) break;
      final saved = widget.storage.loadDayData(key);
      final rawSessions = saved['sessions'] as List?;
      final date = DateTime.tryParse(key) ?? today;
      List<SessionEntry> daySessions;
      if (rawSessions != null) {
        daySessions = rawSessions
            .map((raw) =>
                SessionEntry.fromMap(Map<String, dynamic>.from(raw as Map)))
            .where((s) => !widget.ignoredApps.contains(s.exePath))
            .toList();
      } else {
        daySessions = [];
      }
      days.add(_DayData(date: date, sessions: daySessions));
    }

    final allEmpty = days.every((d) => d.sessions.isEmpty);
    if (allEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No sessions recorded yet.\nEnable "Record detailed sessions" in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final allApps = <String>{};
    for (final d in days) {
      for (final s in d.sessions) {
        allApps.add(s.appName);
      }
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hour labels (shared)
        _buildHourLabels(theme),
        const SizedBox(height: 4),

        // Scrollable day rows
        Expanded(
          child: ListView.separated(
            itemCount: days.length,
            separatorBuilder: (context2, idx) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _buildDayRow(context, days[i], theme, i),
          ),
        ),

        const SizedBox(height: 4),
        // Zoom tip
        Row(
          children: [
            const SizedBox(width: 80),
            Icon(Icons.zoom_in, size: 13,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(
              'Scroll to zoom, drag to pan',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        // Shared legend (clickable to filter)
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            ...allApps.map((name) {
              final isSelected = _filterApp == null || _filterApp == name;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _filterApp = _filterApp == name ? null : name;
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
                            color: _colorForApp(name),
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
            if (_filterApp != null)
              GestureDetector(
                onTap: () => setState(() => _filterApp = null),
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
      ],
    );
  }

  Widget _buildHourLabels(ThemeData theme) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          const SizedBox(width: 80),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final labels = <Widget>[];
                for (var h = 0; h <= 24; h += 3) {
                  final frac = h / 24.0;
                  labels.add(Positioned(
                    left: frac * w - (h == 24 ? 30 : 0),
                    top: 0,
                    child: SizedBox(
                      width: 30,
                      child: Text(
                        TimeUtils.hourLabel(h % 24),
                        textAlign: h == 24 ? TextAlign.right : TextAlign.left,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ));
                }
                return Stack(clipBehavior: Clip.none, children: labels);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(
      BuildContext context, _DayData day, ThemeData theme, int dayIndex) {
    final now = DateTime.now();
    final isToday = day.date.year == now.year &&
        day.date.month == now.month &&
        day.date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = day.date.year == yesterday.year &&
        day.date.month == yesterday.month &&
        day.date.day == yesterday.day;

    final label = isToday
        ? 'Today'
        : isYesterday
            ? 'Yesterday'
            : DateFormat('EEE, MMM d').format(day.date);

    final isZoomed = _zoomedDay == dayIndex && _zoomLevel > 1.0;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 84,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;

                // Determine visible time window
                double startHour = 0;
                double endHour = 24;
                if (isZoomed) {
                  final visibleHours = 24.0 / _zoomLevel;
                  final centerHour = _zoomCenter * 24.0;
                  startHour = (centerHour - visibleHours / 2)
                      .clamp(0.0, 24.0 - visibleHours);
                  endHour = startHour + visibleHours;
                }

                final startMin = startHour * 60;
                final endMin = endHour * 60;
                final visibleMinutes = endMin - startMin;
                final pixelsPerMinute = totalWidth / visibleMinutes;

                return Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      setState(() {
                        _zoomedDay = dayIndex;
                        // Map mouse X to the hour under the cursor
                        final mouseX = event.localPosition.dx / totalWidth;
                        final hourUnderCursor =
                            startHour + mouseX * (endHour - startHour);
                        // Zoom in/out
                        final delta =
                            event.scrollDelta.dy < 0 ? 0.5 : -0.5;
                        final newZoom =
                            (_zoomLevel + delta).clamp(1.0, _maxZoom);
                        // Recompute center so hourUnderCursor stays at mouseX
                        final newVisible = 24.0 / newZoom;
                        final newCenter =
                            (hourUnderCursor - mouseX * newVisible +
                                    newVisible / 2) /
                                24.0;
                        _zoomCenter = newCenter.clamp(0.0, 1.0);
                        _zoomLevel = newZoom;
                        if (_zoomLevel <= 1.0) {
                          _zoomedDay = -1;
                          _zoomLevel = 1.0;
                        }
                      });
                    }
                  },
                  child: GestureDetector(
                    onHorizontalDragUpdate: isZoomed
                        ? (details) {
                            final dragPx = -details.delta.dx;
                            final visibleHours = 24.0 / _zoomLevel;
                            final hoursPerPx = visibleHours / totalWidth;
                            setState(() {
                              _zoomCenter = (_zoomCenter +
                                      dragPx * hoursPerPx / 24.0)
                                  .clamp(0.0, 1.0);
                            });
                          }
                        : null,
                    child: MouseRegion(
                      cursor: isZoomed
                          ? SystemMouseCursors.grab
                          : SystemMouseCursors.basic,
                      onExit: (_) {
                        if (_zoomedDay == dayIndex) {
                          setState(() {
                            _zoomedDay = -1;
                            _zoomLevel = 1.0;
                          });
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                      children: [
                        // Background bar
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Zoomed hour labels overlay
                        if (isZoomed)
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (ctx, c) {
                                final w = c.maxWidth;
                                final labels = <Widget>[];
                                // Pick label interval based on zoom
                                final visibleH = endHour - startHour;
                                final interval = visibleH <= 3
                                    ? 0.5
                                    : visibleH <= 6
                                        ? 1.0
                                        : 2.0;
                                // Start at the first tick >= startHour
                                double h = (startHour / interval).ceil() * interval;
                                while (h < endHour) {
                                  final frac = (h - startHour) / visibleH;
                                  final isWhole = (h % 1) == 0;
                                  final lbl = isWhole
                                      ? TimeUtils.hourLabel(h.toInt())
                                      : '${h.toInt()}:30';
                                  labels.add(Positioned(
                                    left: frac * w,
                                    top: 0,
                                    child: Text(
                                      lbl,
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: theme.colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ));
                                  h += interval;
                                }
                                return Stack(children: labels);
                              },
                            ),
                          ),
                        // Session segments
                        ...((_filterApp != null
                                ? day.sessions.where((s) => s.appName == _filterApp)
                                : day.sessions)
                            .map((s) {
                          final sStartMin =
                              s.start.hour * 60.0 + s.start.minute;
                          final sEndMin = s.end.hour * 60.0 + s.end.minute;
                          // Skip sessions outside visible window
                          if (sEndMin <= startMin || sStartMin >= endMin) {
                            return const SizedBox.shrink();
                          }
                          final clampedStart =
                              sStartMin.clamp(startMin, endMin);
                          final clampedEnd = sEndMin.clamp(startMin, endMin);
                          final segDur =
                              (clampedEnd - clampedStart).clamp(0.5, visibleMinutes);
                          final left =
                              (clampedStart - startMin) * pixelsPerMinute;
                          final maxW = math.max(0.0, totalWidth - left);
                          final width = (segDur * pixelsPerMinute)
                              .clamp(math.min(2.0, maxW), maxW)
                              .toDouble();

                          return Positioned(
                            left: left,
                            width: width,
                            top: isZoomed ? 12 : 2,
                            bottom: 2,
                            child: Tooltip(
                              message:
                                  '${s.appName}${s.windowTitle != null && s.windowTitle!.isNotEmpty ? '\n${s.windowTitle}' : ''}\n${_timeStr(s.start)} \u2013 ${_timeStr(s.end)}\n${TimeUtils.formatShort(s.durationSeconds)}',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _colorForApp(s.appName)
                                      .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          );
                        })),
                      ],
                    ),
                  ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Color _colorForApp(String name) {
    final palette = AppTheme.chartPalette;
    final idx = name.hashCode.abs() % palette.length;
    return palette[idx];
  }

  String _timeStr(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DayData {
  final DateTime date;
  final List<SessionEntry> sessions;
  const _DayData({required this.date, required this.sessions});
}
