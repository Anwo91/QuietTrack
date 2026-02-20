/// Dashboard: at-a-glance view of today's activity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tracker_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/animated_counter.dart';
import '../widgets/animated_card.dart';
import '../widgets/pie_chart_widget.dart';
import '../widgets/hourly_bar_chart.dart';
import '../widgets/media_card.dart';
import '../widgets/monitor_breakdown.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackerProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text(
            'Dashboard',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Today - ${_formatDate(state.date)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Row 1: Total Active + Pie
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 700;
              final children = [
                // Total Active card
                Expanded(
                  flex: wide ? 1 : 0,
                  child: ShimmerWrap(
                    isLoading: state.isLoading,
                    shimmer: const ShimmerDashboardCard(),
                    child: AnimatedCard(
                      index: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Active Time',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedTimeCounter(
                            totalSeconds: state.totalActiveSeconds,
                            hero: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.currentApp != null
                                ? 'Current: ${state.appNames[state.currentApp] ?? "-"}'
                                : 'Idle',                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (wide) const SizedBox(width: 16),
                // Pie chart card
                Expanded(
                  flex: wide ? 1 : 0,
                  child: ShimmerWrap(
                    isLoading: state.isLoading,
                    shimmer: const ShimmerPieChart(),
                    child: AnimatedCard(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Breakdown',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RepaintBoundary(
                            child: AppPieChart(
                              appUsage: state.appUsage,
                              appNames: state.appNames,
                              windowTitleUsage: settings.trackWindowTitles
                                  ? state.windowTitleUsage
                                  : const {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                );
              }
              return Column(children: children);
            },
          ),
          const SizedBox(height: 16),

          // Row 2: Hourly bar chart
          ShimmerWrap(
            isLoading: state.isLoading,
            shimmer: const ShimmerBarChart(),
            child: AnimatedCard(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hourly Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    child: HourlyBarChart(hourlyActive: state.hourlyActive),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Row 3: Media + Monitor (conditional)
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = <Widget>[];

              // Media card
              if (settings.detectMedia) {
                cards.add(
                  Expanded(
                    child: AnimatedCard(
                      index: 3,
                      child: MediaCard(
                        mediaSeconds: state.mediaSeconds,
                        currentMediaApp: state.currentMediaApp,
                        currentMediaTitle: state.currentMediaTitle,
                        mediaAppUsage: state.mediaAppUsage,
                      ),
                    ),
                  ),
                );
              }

              // Monitor breakdown
              if (settings.trackPerMonitor) {
                cards.add(
                  Expanded(
                    child: ShimmerWrap(
                      isLoading: state.isLoading,
                      shimmer: const ShimmerDashboardCard(),
                      child: AnimatedCard(
                        index: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Per-Monitor Activity',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            MonitorBreakdown(monitorUsage: state.monitorUsage),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (cards.isEmpty) return const SizedBox.shrink();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    cards[i],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
