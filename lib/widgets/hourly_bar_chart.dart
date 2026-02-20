/// Hourly activity bar chart (0-23h).
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/time_utils.dart';

class HourlyBarChart extends StatelessWidget {
  final Map<int, int> hourlyActive;

  const HourlyBarChart({super.key, required this.hourlyActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final maxVal = hourlyActive.values.fold<int>(0, (a, b) => a > b ? a : b);
    final double maxY = maxVal > 0 ? (maxVal + 60).toDouble() : 3600.0;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final hour = group.x;
                final secs = rod.toY.round();
                return BarTooltipItem(
                  '${TimeUtils.hourLabel(hour)}\n${TimeUtils.formatShort(secs)}',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.dividerColor.withValues(alpha: 0.3),
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  // Don't show 0 or values at the very top edge
                  if (value <= 0 || value >= maxY) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      TimeUtils.formatShort(value.round()),
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final h = value.toInt();
                  if (h % 3 != 0) return const SizedBox.shrink();
                  return Text(
                    TimeUtils.hourLabel(h),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(24, (h) {
            final val = (hourlyActive[h] ?? 0).toDouble();
            return BarChartGroupData(
              x: h,
              barRods: [
                BarChartRodData(
                  toY: val,
                  width: 10,
                  color: primary.withValues(alpha: val > 0 ? 0.8 : 0.15),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
